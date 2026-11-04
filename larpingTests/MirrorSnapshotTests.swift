import XCTest
@testable import larping

final class MirrorSnapshotTests: XCTestCase {
    private func sample(state: MirrorSnapshot.State = .recording) -> MirrorSnapshot {
        MirrorSnapshot(
            state: state, elapsedSeconds: 754, distanceMeters: 2150.5,
            speedMetersPerSecond: 3.0, sportLabel: "Run", usesPace: true
        )
    }

    func testDictionaryRoundTrip() {
        let original = sample()
        XCTAssertEqual(MirrorSnapshot(dictionary: original.dictionary), original)
    }

    func testEveryStateRoundTrips() {
        for state in [MirrorSnapshot.State.idle, .recording, .paused] {
            let s = sample(state: state)
            XCTAssertEqual(MirrorSnapshot(dictionary: s.dictionary)?.state, state)
        }
    }

    func testMissingFieldIsRejected() {
        var dict = sample().dictionary
        dict.removeValue(forKey: "distance")
        XCTAssertNil(MirrorSnapshot(dictionary: dict))
    }

    func testUnknownStateIsRejected() {
        var dict = sample().dictionary
        dict["state"] = "flying"
        XCTAssertNil(MirrorSnapshot(dictionary: dict))
    }

    func testWrongTypeIsRejected() {
        var dict = sample().dictionary
        dict["elapsed"] = "754"
        XCTAssertNil(MirrorSnapshot(dictionary: dict))
    }

    func testNegativeAndNonFiniteValuesAreRejected() {
        for (key, bad) in [("elapsed", -1), ("distance", -5.0), ("speed", Double.nan), ("distance", Double.infinity)] as [(String, Any)] {
            var dict = sample().dictionary
            dict[key] = bad
            XCTAssertNil(MirrorSnapshot(dictionary: dict), "\(key)=\(bad) should be rejected")
        }
    }

    func testEmptyDictionaryIsRejected() {
        XCTAssertNil(MirrorSnapshot(dictionary: [:]))
    }
}

final class MirrorDisplayTests: XCTestCase {
    func testRunShowsPaceInTheIPhoneFormat() {
        let d = MirrorDisplay(MirrorSnapshot(
            state: .recording, elapsedSeconds: 754, distanceMeters: 2150.5,
            speedMetersPerSecond: 3.0, sportLabel: "Run", usesPace: true
        ))
        XCTAssertEqual(d.time, "12:34")
        XCTAssertEqual(d.distance, "2.15 km")
        XCTAssertEqual(d.rate, "5:33 /km")
        XCTAssertFalse(d.isPaused)
    }

    func testRideShowsSpeed() {
        let d = MirrorDisplay(MirrorSnapshot(
            state: .recording, elapsedSeconds: 3725, distanceMeters: 30000,
            speedMetersPerSecond: 7.0, sportLabel: "Ride", usesPace: false
        ))
        XCTAssertEqual(d.time, "1:02:05")
        XCTAssertEqual(d.rate, "25.2 km/h")
    }

    func testStandingStillShowsDash() {
        let d = MirrorDisplay(MirrorSnapshot(
            state: .recording, elapsedSeconds: 5, distanceMeters: 0,
            speedMetersPerSecond: 0, sportLabel: "Run", usesPace: true
        ))
        XCTAssertEqual(d.rate, Formatters.paceFromSpeed(metersPerSecond: 0))
    }

    func testPausedFlag() {
        XCTAssertTrue(MirrorDisplay(MirrorSnapshot(
            state: .paused, elapsedSeconds: 60, distanceMeters: 100,
            speedMetersPerSecond: 0, sportLabel: "Run", usesPace: true
        )).isPaused)
    }

    func testIdleSnapshotFormatsToZero() {
        let d = MirrorDisplay(.idle)
        XCTAssertEqual(d.time, "0:00")
        XCTAssertEqual(d.distance, "0.00 km")
    }
}

final class MirrorMatchesFormattersTests: XCTestCase {
    /// The watch formats on its own; this keeps it identical to the iPhone.
    func testSameTextAsFormattersAcrossValues() {
        let seconds = [0, 5, 59, 60, 754, 3599, 3600, 3725, 36000]
        let meters = [0.0, 10.0, 999.0, 2150.5, 30000.0, 123456.7]
        let speeds = [0.0, 0.05, 0.1, 0.11, 1.0, 2.5, 3.0, 7.0, 12.3, 400.0]
        for s in seconds {
            for m in meters {
                for v in speeds {
                    for usesPace in [true, false] {
                        let snap = MirrorSnapshot(
                            state: .recording, elapsedSeconds: s, distanceMeters: m,
                            speedMetersPerSecond: v, sportLabel: "x", usesPace: usesPace
                        )
                        let d = MirrorDisplay(snap)
                        XCTAssertEqual(d.time, Formatters.duration(seconds: s))
                        XCTAssertEqual(d.distance, Formatters.distance(meters: m))
                        XCTAssertEqual(
                            d.rate,
                            usesPace ? Formatters.paceFromSpeed(metersPerSecond: v) : Formatters.speed(metersPerSecond: v),
                            "s=\(s) m=\(m) v=\(v) pace=\(usesPace)"
                        )
                    }
                }
            }
        }
    }
}