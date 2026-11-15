import AVFoundation
import MapKit
import UIKit

/// EXPERIMENTAL: renders the route flyover to an MP4 inside the app, with no screen recording and no system
/// permission prompt. Every frame is a separate `MKMapSnapshotter` request for that frame's camera
/// (`FlyoverPlan.state(at:)`), the route, marker and stats are drawn on top, and `AVAssetWriter` encodes the
/// result. Frames are rendered one at a time (nothing is kept in memory across frames), each with a bounded wait.
///
/// Not proven yet (see docs/mury-3d-video-export-feasibility.md): whether snapshots show real 3D geometry at
/// high pitch, how fast frames render on a device, whether the route lines up at high pitch, and whether
/// Apple's terms allow keeping and sharing such a video. A frame that cannot be fetched fails the whole render
/// with a clear message; nothing is substituted by a flat or fake-3D picture.
enum FlyoverRenderer {
    static let frameRate = 20
    /// Output size in pixels (snapshot points x scale 2).
    static let pointSize = CGSize(width: 360, height: 640)
    static let scale: CGFloat = 2
    /// How long one frame may take before it is retried once and then reported as failed.
    static let frameTimeoutSeconds: TimeInterval = 15
    /// How many map images are requested ahead of the one being encoded (they are still encoded in order).
    static let prefetchWindow = 3

    struct Progress {
        let frame: Int
        let total: Int
        let averageSecondsPerFrame: Double
        /// The frame that was just drawn, for a live preview while the video builds.
        let preview: UIImage?
        var secondsRemaining: Double { Double(max(0, total - frame)) * averageSecondsPerFrame }
    }

    struct Output {
        let url: URL
        let frames: Int
        let totalSeconds: Double
    }

    enum RenderError: LocalizedError {
        case frameFailed(Int, String)

        var errorDescription: String? {
            switch self {
            case .frameFailed(let frame, let reason):
                return "The map image for frame \(frame) could not be fetched (\(reason)). Check the connection and try again, or record the screen instead."
            }
        }
    }

    static func render(
        plan: FlyoverPlan,
        timeline: ReplayTimeline,
        routeColor: UIColor,
        symbolName: String,
        savedDistance: String,
        reduceMotion: Bool,
        onProgress: (@MainActor (Progress) -> Void)? = nil
    ) async throws -> Output {
        try Task.checkCancellation()
        let times = FlyoverPlan.frameTimes(clipSeconds: plan.clipSeconds, framesPerSecond: frameRate)
        guard times.count > 1 else { throw ShareVideoComposer.ComposeError.writerFailed("planning the frames") }
        let size = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mury-flyover-\(UUID().uuidString).mp4")

        var completed = false
        defer {
            if !completed { try? FileManager.default.removeItem(at: url) }
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        defer {
            if !completed { writer.cancelWriting() }
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
        )
        guard writer.canAdd(input) else { throw ShareVideoComposer.ComposeError.writerFailed("configuring the video encoder") }
        writer.add(input)
        guard writer.startWriting() else { throw ShareVideoComposer.ComposeError.writerFailed("starting the video encoder", writer.error) }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw ShareVideoComposer.ComposeError.writerFailed("creating the video buffer pool") }

        let clock = ContinuousClock()
        let begin = clock.now
        let states = times.map { plan.state(at: $0) }
        var pending: [Int: Task<MKMapSnapshotter.Snapshot, Error>] = [:]
        defer {
            for task in pending.values { task.cancel() }
        }
        for (index, time) in times.enumerated() {
            try Task.checkCancellation()
            _ = time
            for ahead in index..<min(index + prefetchWindow, times.count) where pending[ahead] == nil {
                let aheadState = states[ahead]
                pending[ahead] = Task { try await fetchSnapshot(for: aheadState, reduceMotion: reduceMotion, frameIndex: ahead) }
            }
            let state = states[index]
            let frame = timeline.sample(at: state.routeElapsedSeconds)
            guard let fetch = pending.removeValue(forKey: index) else { throw ShareVideoComposer.ComposeError.writerFailed("planning the frames") }
            let snapshot = try await fetch.value
            try Task.checkCancellation()

            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw ShareVideoComposer.ComposeError.writerFailed("waiting for the video encoder", writer.error) }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard writer.status == .writing else { throw ShareVideoComposer.ComposeError.writerFailed("encoding a video frame", writer.error) }
            var preview: UIImage?
            try autoreleasepool {
                let image = draw(snapshot: snapshot, state: state, frame: frame, timeline: timeline,
                                 routeColor: routeColor, symbolName: symbolName, savedDistance: savedDistance,
                                 reduceMotion: reduceMotion)
                preview = image
                let buffer = try ShareVideoComposer.pixelBuffer(from: image, size: size, pool: pool)
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: Int32(frameRate))) else {
                    throw ShareVideoComposer.ComposeError.writerFailed("appending a video frame", writer.error)
                }
            }
            let parts = begin.duration(to: clock.now).components
            let elapsed = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            onProgress?(Progress(frame: index + 1, total: times.count, averageSecondsPerFrame: elapsed / Double(index + 1), preview: preview))
        }

        try Task.checkCancellation()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(times.count), timescale: Int32(frameRate)))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ShareVideoComposer.ComposeError.writerFailed("finishing the video file", writer.error) }
        try Task.checkCancellation()
        completed = true
        let parts = begin.duration(to: clock.now).components
        return Output(url: url, frames: times.count, totalSeconds: Double(parts.seconds) + Double(parts.attoseconds) / 1e18)
    }

    // MARK: - Snapshots

    private static func fetchSnapshot(for state: FlyoverPlan.State, reduceMotion: Bool, frameIndex: Int) async throws -> MKMapSnapshotter.Snapshot {
        var lastError: Error = RenderError.frameFailed(frameIndex, "no answer")
        // One retry per frame; after that the render stops instead of inventing a frame.
        for _ in 0..<2 {
            try Task.checkCancellation()
            do {
                return try await requestSnapshot(options: options(for: state, reduceMotion: reduceMotion))
            } catch {
                if Task.isCancelled { throw CancellationError() }
                lastError = error
            }
        }
        throw RenderError.frameFailed(frameIndex, lastError.localizedDescription)
    }

    private static func options(for state: FlyoverPlan.State, reduceMotion: Bool) -> MKMapSnapshotter.Options {
        let options = MKMapSnapshotter.Options()
        options.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            fromDistance: state.distanceMeters,
            pitch: reduceMotion ? 0 : state.pitchDegrees,
            heading: reduceMotion ? 0 : state.headingDegrees)
        options.size = pointSize
        options.scale = scale
        options.mapType = .hybridFlyover
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll
        return options
    }

    private static func requestSnapshot(options: MKMapSnapshotter.Options) async throws -> MKMapSnapshotter.Snapshot {
        let snapshotter = MKMapSnapshotter(options: options)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = SnapshotWaiter(continuation)
                let timeout = DispatchWorkItem {
                    waiter.finish(.failure(URLError(.timedOut)))
                    snapshotter.cancel()
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + frameTimeoutSeconds, execute: timeout)
                snapshotter.start { snapshot, error in
                    timeout.cancel()
                    if let snapshot {
                        waiter.finish(.success(snapshot))
                    } else {
                        waiter.finish(.failure(error ?? URLError(.unknown)))
                    }
                }
            }
        } onCancel: {
            snapshotter.cancel()
        }
    }

    // MARK: - Drawing

    private static func draw(
        snapshot: MKMapSnapshotter.Snapshot,
        state: FlyoverPlan.State,
        frame: ReplayFrame,
        timeline: ReplayTimeline,
        routeColor: UIColor,
        symbolName: String,
        savedDistance: String,
        reduceMotion: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext
            // Own projection with the same camera the picture was requested with: Snapshot.point(for:) placed the
            // route at random spots on tilted frames.
            let camera = FlyoverProjection.Camera(
                centerLatitude: state.centerLatitude, centerLongitude: state.centerLongitude,
                distanceMeters: state.distanceMeters,
                headingDegrees: reduceMotion ? 0 : state.headingDegrees,
                pitchDegrees: reduceMotion ? 0 : state.pitchDegrees)
            func project(_ latitude: Double, _ longitude: Double) -> CGPoint? {
                guard let p = FlyoverProjection.project(latitude: latitude, longitude: longitude, camera: camera,
                                                        width: Double(pointSize.width), height: Double(pointSize.height)) else { return nil }
                return CGPoint(x: p.x, y: p.y)
            }

            func strokeRoute(_ segments: [[ReplayCoordinate]], alpha: CGFloat) {
                cg.setStrokeColor(routeColor.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(4)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                for segment in segments where segment.count > 1 {
                    var drawing = false
                    for point in segment {
                        guard let p = project(point.latitude, point.longitude) else {
                            if drawing { cg.strokePath() }
                            drawing = false
                            continue
                        }
                        if drawing { cg.addLine(to: p) } else { cg.move(to: p); drawing = true }
                    }
                    if drawing { cg.strokePath() }
                }
            }
            strokeRoute(timeline.segments, alpha: 0.3)
            strokeRoute(frame.revealedSegments, alpha: 1)

            if let first = timeline.segments.first?.first, let p = project(first.latitude, first.longitude) {
                cg.setFillColor(UIColor.systemGreen.cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
                cg.setStrokeColor(UIColor.white.cgColor)
                cg.setLineWidth(2.5)
                cg.strokeEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
            }

            if state.phase != .overview, state.markerDrop < 1, let position = frame.position,
               var p = project(position.latitude, position.longitude) {
                p.y -= CGFloat(state.markerDrop) * 360
                let alpha = CGFloat(min(1, (1 - state.markerDrop) * 6))
                let rect = CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)
                cg.setFillColor(routeColor.withAlphaComponent(alpha).cgColor)
                cg.fillEllipse(in: rect)
                cg.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(2)
                cg.strokeEllipse(in: rect)
                let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                if let icon = UIImage(systemName: symbolName, withConfiguration: config)?
                    .withTintColor(UIColor.white.withAlphaComponent(alpha), renderingMode: .alwaysOriginal) {
                    icon.draw(at: CGPoint(x: p.x - icon.size.width / 2, y: p.y - icon.size.height / 2))
                }
            }

            drawStats(state: state, frame: frame, savedDistance: savedDistance)
            drawText("Apple Maps", at: CGPoint(x: 10, y: pointSize.height - 18), size: 10, weight: .medium, alpha: 0.9)
        }
    }

    private static func drawStats(state: FlyoverPlan.State, frame: ReplayFrame, savedDistance: String) {
        let card = CGRect(x: 14, y: pointSize.height - 96, width: pointSize.width - 28, height: 62)
        UIColor.black.withAlphaComponent(0.6).setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 14).fill()
        let columns: [(String, String)] = [
            ("Total distance", savedDistance),
            ("Time", Formatters.duration(seconds: Int(min(state.routeElapsedSeconds, Double(Int.max / 2))))),
            ("Speed", Formatters.speed(metersPerSecond: frame.speedMps)),
        ]
        let width = card.width / 3
        for (index, column) in columns.enumerated() {
            let x = card.minX + 14 + CGFloat(index) * width
            drawText(column.0, at: CGPoint(x: x, y: card.minY + 10), size: 11, weight: .regular, alpha: 0.75)
            drawText(column.1, at: CGPoint(x: x, y: card.minY + 28), size: 18, weight: .semibold, alpha: 1)
        }
    }

    private static func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha),
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}

/// Resumes a continuation exactly once, whichever of the snapshot callback and the timeout gets there first.
nonisolated private final class SnapshotWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<MKMapSnapshotter.Snapshot, Error>?

    init(_ continuation: CheckedContinuation<MKMapSnapshotter.Snapshot, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Swift.Result<MKMapSnapshotter.Snapshot, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
