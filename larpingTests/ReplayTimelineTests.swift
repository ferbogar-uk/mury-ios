import XCTest
@testable import larping

final class ReplayTimelineTests: XCTestCase {
    func testIrregularSamplesUseTimeRatherThanIndex() {
        let start = Date(timeIntervalSince1970: 1000)
        let points = [0.0, 2, 10].map {
            ReplayPoint(timestamp: start.addingTimeInterval($0), latitude: 0, longitude: $0 / 10000)
        }
        let timeline = ReplayTimeline(points: points, startedAt: start, endedAt: nil)
        XCTAssertEqual(timeline.sample(at: 1).position!.longitude, 0.0001, accuracy: 0.0000001)
        XCTAssertEqual(timeline.sample(at: 9).elapsedSeconds, 9)
        XCTAssertEqual(timeline.sample(at: 1).revealedSegments[0].count, 2)
    }

    func testGapsDoNotRevealConnectingLineWhenSeekingBackwards() {
        let start = Date(timeIntervalSince1970: 1000)
        let points = [0.0, 2, 40, 42].map {
            ReplayPoint(timestamp: start.addingTimeInterval($0), latitude: 0, longitude: $0 / 100000)
        }
        let timeline = ReplayTimeline(points: points, startedAt: start, endedAt: nil)
        XCTAssertEqual(timeline.segments.count, 2)
        XCTAssertEqual(timeline.sample(at: 41).revealedSegments.count, 2)
        XCTAssertEqual(timeline.sample(at: 1).revealedSegments.count, 1)
        XCTAssertNil(timeline.sample(at: 30).position)
    }

    func testDuplicateValidationBoundsAndMissingMetrics() {
        let start = Date(timeIntervalSince1970: 1000)
        let timeline = ReplayTimeline(points: [
            ReplayPoint(timestamp: start, latitude: 0, longitude: 0, altitudeMeters: .nan, speedMps: -1),
            ReplayPoint(timestamp: start, latitude: 1, longitude: 1),
            ReplayPoint(timestamp: start.addingTimeInterval(2), latitude: 0, longitude: 0.0002),
            ReplayPoint(timestamp: start.addingTimeInterval(3), latitude: 91, longitude: 0),
            ReplayPoint(timestamp: start.addingTimeInterval(5), latitude: 0, longitude: 0)
        ], startedAt: start, endedAt: start.addingTimeInterval(4))
        XCTAssertEqual(timeline.duration, 4)
        XCTAssertEqual(timeline.segments.flatMap { $0 }.count, 2)
        XCTAssertEqual(timeline.sample(at: 0).position?.latitude, 0)
        XCTAssertNil(timeline.sample(at: 1).altitudeMeters)
        XCTAssertNil(timeline.sample(at: 1).speedMps)
        XCTAssertEqual(timeline.sample(at: .nan).elapsedSeconds, 0)
    }

    func testMissingTailDoesNotHoldAMeasuredPositionUntilSavedEnd() {
        let start = Date(timeIntervalSince1970: 1000)
        let timeline = ReplayTimeline(points: [
            ReplayPoint(timestamp: start, latitude: 0, longitude: 0),
            ReplayPoint(timestamp: start.addingTimeInterval(2), latitude: 0, longitude: 0.0002, speedMps: 3)
        ], startedAt: start, endedAt: start.addingTimeInterval(10))
        XCTAssertNotNil(timeline.sample(at: 2).position)
        XCTAssertNil(timeline.sample(at: 9).position)
        XCTAssertNil(timeline.sample(at: 9).speedMps)
    }

    func testPlaybackStopsAndRestartsWithoutAdvancingWhilePaused() {
        var playback = ReplayPlayback(duration: 10)
        playback.play()
        playback.setSpeed(4)
        playback.advance(by: 3)
        XCTAssertEqual(playback.elapsedSeconds, 10)
        XCTAssertFalse(playback.isPlaying)
        playback.play()
        XCTAssertEqual(playback.elapsedSeconds, 0)
        playback.pause()
        playback.advance(by: 2)
        XCTAssertEqual(playback.elapsedSeconds, 0)
        playback.setSpeed(3)
        XCTAssertEqual(playback.speed, 4)
    }
}
