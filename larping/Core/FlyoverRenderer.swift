import AVFoundation
import MapKit
import UIKit

/// EXPERIMENTAL: renders the route flyover to an MP4 inside the app, with no screen recording and no system
/// permission prompt. Since build 39 every frame is copied from one live Apple 3D map view (`DirectMapCapture`)
/// moved to that frame's camera (`FlyoverPlan.state(at:)`); the route, marker and stats are drawn on top, and
/// `AVAssetWriter` encodes the result. The old method (a new `MKMapSnapshotter` per frame) was removed: each
/// snapshot kept memory the map engine never gave back.
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

    struct Progress {
        let frame: Int
        let total: Int
        let averageSecondsPerFrame: Double
        /// The frame that was just drawn, for a live preview while the video builds.
        let preview: UIImage?
        /// Memory the app is using right now, in MB (0 if unknown). Shown while rendering to find what grows.
        var memoryMegabytes: Int = 0
        /// Average memory growth per frame by stage ("snapshot +9, draw +3, encode +3 MB"), to find what keeps memory.
        var stageText: String = ""
        var secondsRemaining: Double { Double(max(0, total - frame)) * averageSecondsPerFrame }
    }

    struct Output {
        let url: URL
        let frames: Int
        let totalSeconds: Double
    }

    /// The render stops cleanly above this footprint instead of waiting for the system to close the app (it did
    /// at about 3.3 GB on an iPhone in build 18).
    static let memoryLimitMegabytes = 2800
    /// Checked at frame 12: slower than this and a 30 s clip would take more than about 20 minutes.
    static let maxSecondsPerFrame = 1.5

    enum RenderError: LocalizedError {
        case blackMap
        case tooSlow(Int, Double)
        case outOfMemory(Int, Int, String)

        var errorDescription: String? {
            switch self {
            case .outOfMemory(let frame, let megabytes, let stages):
                return "The render stopped at frame \(frame) because it was using \(megabytes) MB of memory and iOS would have closed MURY. Growth: \(stages). Try a shorter clip."

            case .tooSlow(let frame, let seconds):
                return "The render stopped at frame \(frame): the 3D map needs \(String(format: "%.1f", seconds)) s per frame on this phone, so the clip would take far too long. Use Record video instead."
            case .blackMap:
                return "The 3D map came out black when copied on this phone, so Render in app can't work here. Use Record video instead."
            }
        }
    }

    static func render(
        plan: FlyoverPlan,
        timeline: ReplayTimeline,
        routeColor: UIColor,
        symbolName: String,
        overlayInfo: VideoOverlayInfo,
        reduceMotion: Bool,
        capture: DirectMapCapture,
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

        // Leaves a note on the phone that is removed when this function ends in any normal way. If the system
        // kills the app mid-render the note stays, and the next launch reports where it stopped.
        let crashLog = RenderCrashLog.shared
        crashLog.begin(total: times.count,
                       appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
                       systemVersion: UIDevice.current.systemVersion,
                       device: UIDevice.current.model)
        defer { crashLog.clear() }

        let clock = ContinuousClock()
        let begin = clock.now
        let states = times.map { plan.state(at: $0) }
        // Memory the app already holds before the first picture: tells whether the growth starts in the render or before it.
        let startMegabytes = currentMemoryMegabytes()
        var grewBySnapshot = 0, grewByDraw = 0, grewByEncode = 0, grewByScreen = 0, screenFrames = 0
        for (index, time) in times.enumerated() {
            try Task.checkCancellation()
            _ = time
            let state = states[index]
            let frame = timeline.sample(at: state.routeElapsedSeconds)
            let memoryBefore = currentMemoryMegabytes()
            let mapImage = await capture.capture(state: state, reduceMotion: reduceMotion)
            try Task.checkCancellation()
            // A few frames in (the very first can still be loading): a black copy means this phone can't do it.
            if index == min(5, times.count - 1), DirectMapCapture.looksBlack(mapImage) {
                throw RenderError.blackMap
            }
            let memoryAfterSnapshot = currentMemoryMegabytes()
            grewBySnapshot += memoryAfterSnapshot - memoryBefore

            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw ShareVideoComposer.ComposeError.writerFailed("waiting for the video encoder", writer.error) }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard writer.status == .writing else { throw ShareVideoComposer.ComposeError.writerFailed("encoding a video frame", writer.error) }
            var preview: UIImage?
            var memoryAfterDraw = memoryAfterSnapshot
            try autoreleasepool {
                let image = draw(mapImage: mapImage, state: state, frame: frame, timeline: timeline,
                                 routeColor: routeColor, symbolName: symbolName, overlayInfo: overlayInfo,
                                 reduceMotion: reduceMotion, capture: capture)
                // A full-size picture goes to the screen only every 4th frame, so the screen never holds many.
                preview = index % 4 == 0 ? image : nil
                memoryAfterDraw = currentMemoryMegabytes()
                let buffer = try ShareVideoComposer.pixelBuffer(from: image, size: size, pool: pool)
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: Int32(frameRate))) else {
                    throw ShareVideoComposer.ComposeError.writerFailed("appending a video frame", writer.error)
                }
            }
            let memoryNow = currentMemoryMegabytes()
            grewByDraw += memoryAfterDraw - memoryAfterSnapshot
            grewByEncode += memoryNow - memoryAfterDraw
            let done = index + 1
            let stages = "start \(startMegabytes) MB, map \(grewBySnapshot / done), draw \(grewByDraw / done), encode \(grewByEncode / done) MB per frame, screen \(grewByScreen / max(screenFrames, 1)) MB per picture shown"
            crashLog.update(frame: done, phase: String(describing: state.phase), megabytes: memoryNow, note: stages)
            if memoryNow > memoryLimitMegabytes { throw RenderError.outOfMemory(done, memoryNow, stages) }
            let parts = begin.duration(to: clock.now).components
            let elapsed = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            if index + 1 == 12, elapsed / 12 > maxSecondsPerFrame { throw RenderError.tooSlow(index + 1, elapsed / 12) }
            onProgress?(Progress(frame: index + 1, total: times.count, averageSecondsPerFrame: elapsed / Double(index + 1), preview: preview,
                                       memoryMegabytes: memoryNow, stageText: stages))
            if preview != nil {
                // Let the screen draw the new picture, then see how much memory that cost.
                try? await Task.sleep(for: .milliseconds(30))
                grewByScreen += currentMemoryMegabytes() - memoryNow
                screenFrames += 1
            }
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

    /// The app's physical memory footprint (the number the system kills by), in MB.
    static func currentMemoryMegabytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : 0
    }

    // MARK: - Drawing

    private static func draw(
        mapImage: UIImage,
        state: FlyoverPlan.State,
        frame: ReplayFrame,
        timeline: ReplayTimeline,
        routeColor: UIColor,
        symbolName: String,
        overlayInfo: VideoOverlayInfo,
        reduceMotion: Bool,
        capture: DirectMapCapture
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        // Projected here, on the main actor, with the live map view's own projection for the frame just captured
        // (build 42). The earlier hand-made one assumed a 30 degree field of view over flat ground and the route
        // drifted off the streets. The drawing closure below only uses these ready-made points.
        func projectAll(_ segments: [[ReplayCoordinate]]) -> [[CGPoint?]] {
            segments.map { segment in segment.map { capture.project(latitude: $0.latitude, longitude: $0.longitude) } }
        }
        let fullRoute = projectAll(timeline.segments)
        let revealedRoute = projectAll(frame.revealedSegments)
        let startPoint = timeline.segments.first?.first.flatMap { capture.project(latitude: $0.latitude, longitude: $0.longitude) }
        let markerPoint = frame.position.flatMap { capture.project(latitude: $0.latitude, longitude: $0.longitude) }
        return renderer.image { context in
            mapImage.draw(in: CGRect(origin: .zero, size: pointSize))
            let cg = context.cgContext
            func strokeRoute(_ segments: [[CGPoint?]], alpha: CGFloat) {
                cg.setStrokeColor(routeColor.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(4)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                for segment in segments where segment.count > 1 {
                    var drawing = false
                    for projected in segment {
                        guard let p = projected else {
                            if drawing { cg.strokePath() }
                            drawing = false
                            continue
                        }
                        if drawing { cg.addLine(to: p) } else { cg.move(to: p); drawing = true }
                    }
                    if drawing { cg.strokePath() }
                }
            }
            strokeRoute(fullRoute, alpha: 0.3)
            strokeRoute(revealedRoute, alpha: 1)

            if let p = startPoint {
                cg.setFillColor(UIColor.systemGreen.cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
                cg.setStrokeColor(UIColor.white.cgColor)
                cg.setLineWidth(2.5)
                cg.strokeEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
            }

            if state.phase != .overview, state.markerDrop < 1, var p = markerPoint {
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

            drawLogo(in: cg)
            drawCard(info: overlayInfo, progress: state.routeProgress, in: cg)
            drawText("Apple Maps", at: CGPoint(x: 10, y: pointSize.height - 18), size: 10, weight: .medium, alpha: 0.9)
        }
    }

    /// The red MURY logo across the top with the same 3D look as the live screens (`VideoLogo`).
    private static func drawLogo(in cg: CGContext) {
        guard let logo = VideoLogo.image else { return }
        let width = VideoLogo.width
        let height = width * logo.size.height / max(logo.size.width, 1)
        let rect = CGRect(x: (pointSize.width - width) / 2, y: 62, width: width, height: height)
        let side = logo.withTintColor(VideoLogo.depthColor, renderingMode: .alwaysOriginal)
        cg.saveGState()
        cg.setShadow(offset: VideoLogo.shadowOffset, blur: VideoLogo.shadowBlur, color: VideoLogo.shadowColor.cgColor)
        // One transparency layer so the shadow is cast once by the whole block, not by every copy.
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        for layer in (1...VideoLogo.depthLayers).reversed() {
            side.draw(in: rect.offsetBy(dx: 0, dy: CGFloat(layer)))
        }
        logo.draw(in: rect)
        cg.endTransparencyLayer()
        cg.restoreGState()
    }

    /// Strava-style card: avatar, name, activity, three numbers and a thin progress bar.
    private static func drawCard(info: VideoOverlayInfo, progress: Double, in cg: CGContext) {
        let card = CGRect(x: 14, y: pointSize.height - 126, width: pointSize.width - 28, height: 104)
        UIColor.black.withAlphaComponent(0.55).setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 18).fill()

        let avatar = CGRect(x: card.minX + 14, y: card.minY + 12, width: 34, height: 34)
        UIColor.white.withAlphaComponent(0.22).setFill()
        UIBezierPath(ovalIn: avatar).fill()
        let initials = info.initials as NSString
        let initialsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: UIColor.white,
        ]
        let initialsSize = initials.size(withAttributes: initialsAttributes)
        initials.draw(at: CGPoint(x: avatar.midX - initialsSize.width / 2, y: avatar.midY - initialsSize.height / 2),
                      withAttributes: initialsAttributes)

        let textX = avatar.maxX + 10
        drawText(info.athleteName, at: CGPoint(x: textX, y: card.minY + 11), size: 14, weight: .bold, alpha: 1)
        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        var titleX = textX
        if let icon = UIImage(systemName: info.symbolName, withConfiguration: config)?
            .withTintColor(UIColor.white.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
            icon.draw(at: CGPoint(x: textX, y: card.minY + 31))
            titleX += icon.size.width + 5
        }
        drawText(info.activityTitle, at: CGPoint(x: titleX, y: card.minY + 30), size: 12, weight: .regular, alpha: 0.85)

        let columns: [(String, String)] = [
            ("Distance", info.distance), (info.paceLabel, info.pace), ("Elevation", info.elevation),
        ]
        let width = (card.width - 28) / 3
        for (index, column) in columns.enumerated() {
            let x = card.minX + 14 + CGFloat(index) * width
            drawText(column.0, at: CGPoint(x: x, y: card.minY + 54), size: 11, weight: .regular, alpha: 0.75)
            drawText(column.1, at: CGPoint(x: x, y: card.minY + 68), size: 17, weight: .bold, alpha: 1)
        }

        let bar = CGRect(x: card.minX + 14, y: card.maxY - 12, width: card.width - 28, height: 3)
        UIColor.white.withAlphaComponent(0.3).setFill()
        UIBezierPath(roundedRect: bar, cornerRadius: 1.5).fill()
        let done = CGFloat(min(1, max(0, progress)))
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * done, height: 3), cornerRadius: 1.5).fill()
    }

    private static func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha),
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}
