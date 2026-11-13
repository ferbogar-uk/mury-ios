import AVFoundation
import CoreLocation
import MapKit
import UIKit

/// Renders the route draw-in as an actual video file over the map background
/// (same visual language as the map image template): one real MapKit snapshot
/// fetched once, then `composeMapCard(...routeRevealFraction:)` drawn per frame
/// so the route reveals over the map without thousands of per-frame tile
/// fetches. Output goes to a temporary file and is never persisted.
enum ShareVideoComposer {
    enum ClipDuration: Int, CaseIterable, Identifiable {
        case fifteen = 15, thirty = 30, sixty = 60
        var id: Int { rawValue }
    }
    static let frameRate: Int32 = 30

    enum ComposeError: LocalizedError {
        case writerFailed(String, Error? = nil)

        var errorDescription: String? {
            switch self {
            case .writerFailed(let operation, let underlying):
                return "Video export failed while \(operation). Please try again." + (underlying.map { " " + $0.localizedDescription } ?? "")
            }
        }
    }

    static func composeVideo(snapshot: MKMapSnapshotter.Snapshot?, coordinates: [CLLocationCoordinate2D], stats: ShareImageComposer.Stats, style: ShareStyle, duration: ClipDuration = .thirty, segments: [[CLLocationCoordinate2D]]? = nil, onProgress: (@MainActor (Double) -> Void)? = nil) async throws -> URL {
        try Task.checkCancellation()
        let composer = ShareImageComposer(style: style)
        let route = ShareRoute(segments: segments ?? [coordinates])
        let fullCoordinates = route.segments.flatMap { $0 }
        onProgress?(0)
        let size = ShareImageComposer.canvasSize
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mury-share-\(UUID().uuidString).mp4")

        var completed = false
        defer {
            if !completed { try? FileManager.default.removeItem(at: url) }
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        defer {
            if !completed { writer.cancelWriting() }
        }
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
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
        guard writer.canAdd(input) else { throw ComposeError.writerFailed("configuring the video encoder") }
        writer.add(input)
        guard writer.startWriting() else { throw ComposeError.writerFailed("starting the video encoder", writer.error) }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw ComposeError.writerFailed("creating the video buffer pool") }

        let totalFrames = duration.rawValue * Int(frameRate)
        for frame in 0..<totalFrames {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw ComposeError.writerFailed("waiting for the video encoder", writer.error) }
                try await Task.sleep(for: .milliseconds(2))
            }
            try Task.checkCancellation()
            guard writer.status == .writing else { throw ComposeError.writerFailed("encoding a video frame", writer.error) }
            // Drain UIKit temporaries before yielding; do not retain a frame across suspension.
            try autoreleasepool {
                let progress = Double(frame) / Double(totalFrames - 1)
                let image = composer.composeMapCard(
                    snapshot: snapshot,
                    coordinates: coordinates,
                    stats: stats,
                    routeRevealFraction: progress,
                    revealedSegments: route.revealedSegments(at: progress),
                    routeCoordinates: fullCoordinates
                )
                let buffer = try pixelBuffer(from: image, size: size, pool: pool)
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) else {
                    throw ComposeError.writerFailed("appending a video frame", writer.error)
                }
            }
            onProgress?(Double(frame + 1) / Double(totalFrames + 1))
            await Task.yield()
        }

        try Task.checkCancellation()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(totalFrames), timescale: frameRate))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ComposeError.writerFailed("finishing the video file", writer.error) }
        try Task.checkCancellation()
        completed = true
        onProgress?(1)
        return url
    }

    static func pixelBuffer(from image: UIImage, size: CGSize, pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw ComposeError.writerFailed("allocating a video frame (Core Video \(status))")
        }

        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
            throw ComposeError.writerFailed("accessing a video frame")
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        guard let context, let cgImage = image.cgImage else {
            throw ComposeError.writerFailed("drawing a video frame")
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}