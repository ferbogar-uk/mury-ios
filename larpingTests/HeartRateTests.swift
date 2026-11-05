import XCTest
@testable import larping

final class HeartRateTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_793_000_000)

    private func reading(_ bpm: Double = 142) -> HeartRateReading {
        HeartRateReading(beatsPerMinute: bpm, date: t0)!
    }

    // MARK: - Validation

    func testPlausibleValueIsAccepted() {
        XCTAssertEqual(reading(142).beatsPerMinute, 142)
    }

    func testValueIsRoundedToWholeBeats() {
        XCTAssertEqual(reading(141.4).beatsPerMinute, 141)
        XCTAssertEqual(reading(141.5).beatsPerMinute, 142)
    }

    func testRangeBoundsAreInclusive() {
        XCTAssertNotNil(HeartRateReading(beatsPerMinute: 30, date: t0))
        XCTAssertNotNil(HeartRateReading(beatsPerMinute: 230, date: t0))
    }

    func testGlitchesAreRejected() {
        let glitches: [Double] = [0, -1, 29.9, 230.1, 400, .nan, .infinity, -.infinity]
        for bad in glitches {
            XCTAssertNil(HeartRateReading(beatsPerMinute: bad, date: t0), "\(bad)")
        }
    }

    // MARK: - Message

    func testDictionaryRoundTrip() {
        let original = reading(151)
        XCTAssertEqual(HeartRateReading(dictionary: original.dictionary), original)
    }

    func testMalformedDictionariesAreRejected() {
        XCTAssertNil(HeartRateReading(dictionary: [:]))
        XCTAssertNil(HeartRateReading(dictionary: ["heartRate": 142]))
        XCTAssertNil(HeartRateReading(dictionary: ["heartRate": "142", "heartRateDate": 1.0]))
        XCTAssertNil(HeartRateReading(dictionary: ["heartRate": 142, "heartRateDate": Double.nan]))
        XCTAssertNil(HeartRateReading(dictionary: ["heartRate": 12, "heartRateDate": 1.0]))
    }

    func testOtherMessagesAreNotMistakenForAHeartRate() {
        let snapshot = MirrorSnapshot(
            state: .recording, elapsedSeconds: 60, distanceMeters: 100,
            speedMetersPerSecond: 3, sportLabel: "Run", usesPace: true
        )
        XCTAssertNil(HeartRateReading(dictionary: snapshot.dictionary))
        XCTAssertNil(HeartRateReading(dictionary: WatchCommand.pause.dictionary))
    }

    func testAHeartRateIsNotMistakenForOtherMessages() {
        let dict = reading().dictionary
        XCTAssertNil(MirrorSnapshot(dictionary: dict))
        XCTAssertNil(WatchCommand(dictionary: dict))
    }

    // MARK: - Display

    func testFreshReadingIsShown() {
        let display = HeartRateDisplay(reading(142), now: t0.addingTimeInterval(3))
        XCTAssertEqual(display.text, "142")
        XCTAssertTrue(display.isLive)
    }

    func testReadingAtTheLimitIsStillShown() {
        let display = HeartRateDisplay(reading(142), now: t0.addingTimeInterval(15))
        XCTAssertEqual(display.text, "142")
        XCTAssertTrue(display.isLive)
    }

    func testStaleReadingShowsADash() {
        let display = HeartRateDisplay(reading(142), now: t0.addingTimeInterval(15.1))
        XCTAssertEqual(display.text, "\u{2013}")
        XCTAssertFalse(display.isLive)
    }

    func testNoReadingShowsADash() {
        let display = HeartRateDisplay(nil, now: t0)
        XCTAssertEqual(display.text, "\u{2013}")
        XCTAssertFalse(display.isLive)
    }

    func testReadingFromTheSlightFutureIsShown() {
        let display = HeartRateDisplay(reading(142), now: t0.addingTimeInterval(-2))
        XCTAssertEqual(display.text, "142")
        XCTAssertTrue(display.isLive)
    }

    // MARK: - Sensor plan

    func testSensorFollowsTheRecording() {
        typealias Plan = HeartRateSensorPlan
        XCTAssertEqual(Plan.action(mirrored: .recording, sensor: .stopped), .start)
        XCTAssertEqual(Plan.action(mirrored: .recording, sensor: .running), .nothing)
        XCTAssertEqual(Plan.action(mirrored: .recording, sensor: .paused), .resume)
        XCTAssertEqual(Plan.action(mirrored: .paused, sensor: .stopped), .nothing)
        XCTAssertEqual(Plan.action(mirrored: .paused, sensor: .running), .pause)
        XCTAssertEqual(Plan.action(mirrored: .paused, sensor: .paused), .nothing)
        XCTAssertEqual(Plan.action(mirrored: .idle, sensor: .stopped), .nothing)
        XCTAssertEqual(Plan.action(mirrored: .idle, sensor: .running), .stop)
        XCTAssertEqual(Plan.action(mirrored: .idle, sensor: .paused), .stop)
    }
}
