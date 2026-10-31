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

    enum ComposeError: Error {
        case writerFailed
    }

    static func composeVideo(snapshot: MKMapSnapshotter.Snapshot?, coordinates: [CLLocationCoordinate2D], stats: ShareImageComposer.Stats, style: ShareStyle) async throws -> URL {
        try Task.checkCancellation()
        let composer = ShareImageComposer(style: style)
        let size = ShareImageComposer.canvasSize
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mury-share-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        var completed = false
        defer {
            if !completed {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: url)
            }
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
            ]
        )
        writer.add(input)
        guard writer.startWriting() else { throw ComposeError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(duration * Double(frameRate))
        for frame in 0..<totalFrames {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw ComposeError.writerFailed }
                try await Task.sleep(for: .milliseconds(2))
            }
            let progress = Double(frame) / Double(totalFrames - 1)
            let image = composer.composeMapCard(
                snapshot: snapshot,
                coordinates: coordinates,
                stats: stats,
                routeRevealFraction: progress
            )
            guard let buffer = pixelBuffer(from: image, size: size) else { throw ComposeError.writerFailed }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) else { throw ComposeError.writerFailed }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ComposeError.writerFailed }
        try Task.checkCancellation()
        completed = true
        return url
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
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
        guard let context, let cgImage = image.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}