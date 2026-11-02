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
    static let duration: TimeInterval = 6
    static let frameRate: Int32 = 60

    enum ComposeError: LocalizedError {
        case writerFailed(String)

        var errorDescription: String? {
            switch self {
            case .writerFailed(let operation):
                return "Video export failed while \(operation). Please try again."
            }
        }
    }

    static func composeVideo(snapshot: MKMapSnapshotter.Snapshot?, coordinates: [CLLocationCoordinate2D], stats: ShareImageComposer.Stats, style: ShareStyle) async throws -> URL {
        try Task.checkCancellation()
        let composer = ShareImageComposer(style: style)
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
        guard writer.startWriting() else { throw ComposeError.writerFailed("starting the video encoder") }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw ComposeError.writerFailed("creating the video buffer pool") }

        let totalFrames = Int(duration * Double(frameRate))
        for frame in 0..<totalFrames {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw ComposeError.writerFailed("waiting for the video encoder") }
                try await Task.sleep(for: .milliseconds(2))
            }
            try Task.checkCancellation()
            guard writer.status == .writing else { throw ComposeError.writerFailed("encoding a video frame") }
            // Drain UIKit temporaries before yielding; do not retain a frame across suspension.
            try autoreleasepool {
                let progress = Double(frame) / Double(totalFrames - 1)
                let image = composer.composeMapCard(
                    snapshot: snapshot,
                    coordinates: coordinates,
                    stats: stats,
                    routeRevealFraction: progress
                )
                let buffer = try pixelBuffer(from: image, size: size, pool: pool)
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) else {
                    throw ComposeError.writerFailed("appending a video frame")
                }
            }
            await Task.yield()
        }

        try Task.checkCancellation()
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ComposeError.writerFailed("finishing the video file") }
        try Task.checkCancellation()
        completed = true
        return url
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize, pool: CVPixelBufferPool) throws -> CVPixelBuffer {
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