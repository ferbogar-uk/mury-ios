import AVFoundation
import CoreLocation
import Darwin
import SwiftUI
import XCTest
@testable import larping

@MainActor
final class ShareVideoComposerTests: XCTestCase {
    func testCompleteExportProducesReadablePortraitMP4() async throws {
        let stats = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Run", distance: "1 km", duration: "5:00", paceOrSpeed: "5:00", date: "Jan 1, 2026")
        // Synthetic coordinates and a nil snapshot keep the full render independent of map tiles.
        let coordinates = [CLLocationCoordinate2D(latitude: 1, longitude: 1), CLLocationCoordinate2D(latitude: 1.001, longitude: 1.001)]
        let peakRSSBefore = peakResidentBytes()
        var peakRSSAfter: Int?
        var exportObservation: String?
        let heartbeat = ExportHeartbeat()
        let observer = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(10)) } catch { return }
                guard !Task.isCancelled else { return }
                heartbeat.recordTick()
            }
        }
        defer {
            observer.cancel()
            if exportObservation == nil { heartbeat.recordTick() }
            let summary = "\(exportObservation ?? heartbeat.summary), processLifetimePeakRSSBeforeBytes=\(String(describing: peakRSSBefore)), processLifetimePeakRSSAfterBytes=\(String(describing: peakRSSAfter ?? peakResidentBytes())). RSS is a process-lifetime high-water mark, not export-exclusive memory."
            print("Complete export observation: \(summary)")
            let observation = XCTAttachment(string: summary)
            observation.name = "Complete export resource and responsiveness observation"
            observation.lifetime = .keepAlways
            add(observation)
        }

        let url = try await ShareVideoComposer.composeVideo(snapshot: nil, coordinates: coordinates, stats: stats, style: BrandTheme.mury.shareStyle(for: .light))
        observer.cancel()
        heartbeat.recordTick()
        exportObservation = heartbeat.summary
        peakRSSAfter = peakResidentBytes()
        defer {
            do {
                try FileManager.default.removeItem(at: url)
                XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            } catch {
                XCTFail("Could not clean up this test's completed export: \(error)")
            }
        }

        XCTAssertEqual(url.pathExtension, "mp4")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertGreaterThan((attributes[.size] as? NSNumber)?.intValue ?? 0, 0)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(tracks.count, 1)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1920))
        let transform = try await track.load(.preferredTransform)
        XCTAssertEqual(transform, .identity)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(duration), 6, accuracy: 1.0 / 60)
        let frameRate = try await track.load(.nominalFrameRate)
        XCTAssertEqual(frameRate, 60, accuracy: 0.01)
        let formats = try await track.load(.formatDescriptions)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(formats.first)), kCMVideoCodecType_H264)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            XCTFail("Reader rejected the video decoder output")
            return
        }
        reader.add(output)
        guard reader.startReading() else {
            XCTFail("Reader could not start: \(String(describing: reader.error))")
            return
        }
        defer { reader.cancelReading() }
        var frameCount = 0
        var previousTime = CMTime.invalid
        // Drain decoded buffers without retaining an entire clip in the test itself.
        while autoreleasepool(invoking: {
            guard let sample = output.copyNextSampleBuffer() else { return false }
            let image = CMSampleBufferGetImageBuffer(sample)
            XCTAssertNotNil(image)
            if let image {
                XCTAssertEqual(CVPixelBufferGetWidth(image), 1080)
                XCTAssertEqual(CVPixelBufferGetHeight(image), 1920)
            }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            XCTAssertTrue(time.isValid)
            XCTAssertEqual(CMTimeGetSeconds(time), Double(frameCount) / 60, accuracy: 0.001)
            if previousTime.isValid { XCTAssertGreaterThan(CMTimeCompare(time, previousTime), 0) }
            previousTime = time
            frameCount += 1
            return true
        }) {}
        XCTAssertEqual(reader.status, .completed, "Incomplete decode: \(String(describing: reader.error))")
        XCTAssertEqual(frameCount, 360)
    }

    private func peakResidentBytes() -> Int? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        // Darwin reports ru_maxrss in bytes; this is the process lifetime peak.
        return Int(usage.ru_maxrss)
    }

    @MainActor
    private final class ExportHeartbeat {
        private let started = ProcessInfo.processInfo.systemUptime
        private var previous = ProcessInfo.processInfo.systemUptime
        private var ticks = 0
        private var longestGap: TimeInterval = 0

        func recordTick() {
            let now = ProcessInfo.processInfo.systemUptime
            longestGap = max(longestGap, now - previous)
            previous = now
            ticks += 1
        }

        var summary: String {
            "elapsedSeconds=\(ProcessInfo.processInfo.systemUptime - started), mainActorTicks=\(ticks), longestObservedGapSeconds=\(longestGap). Observational only; simulator scheduling is not device responsiveness or a memory measurement."
        }
    }

    func testCancelledExportDoesNotReturnAVideo() async {
        let stats = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Run", distance: "1 km", duration: "5:00", paceOrSpeed: "5:00", date: "Jan 1, 2026")
        let task = Task {
            try await ShareVideoComposer.composeVideo(snapshot: nil, coordinates: [], stats: stats, style: BrandTheme.mury.shareStyle(for: .light))
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled export must not produce a shareable video")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}
