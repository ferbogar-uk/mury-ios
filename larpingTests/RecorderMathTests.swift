import XCTest
@testable import larping

final class RecorderMathTests: XCTestCase {
    /// A fix on a north-going line near the equator: each 0.001 deg of latitude is ~111.2 m.
    private func fix(
        lat: Double = 0, lon: Double = 0, alt: Double = 10,
        hAcc: Double = 5, vAcc: Double = 5, speed: Double = 3
    ) -> GPSFix {
        GPSFix(latitude: lat, longitude: lon, altitude: alt,
               horizontalAccuracy: hAcc, verticalAccuracy: vAcc, speed: speed)
    }

    func testFirstFixAddsNoDistance() {
        var m = RecorderMath()
        XCTAssertEqual(m.add(fix(), isRecording: true), .accepted)
        XCTAssertEqual(m.distanceMeters, 0)
    }

    func testDistanceAccumulatesBetweenFixes() {
        var m = RecorderMath()
        _ = m.add(fix(lat: 0.000), isRecording: true)
        _ = m.add(fix(lat: 0.001), isRecording: true)
        _ = m.add(fix(lat: 0.002), isRecording: true)
        XCTAssertEqual(m.distanceMeters, 222.4, accuracy: 0.5)
    }

    func testNotRecordingIgnoresFixes() {
        var m = RecorderMath()
        XCTAssertEqual(m.add(fix(), isRecording: false), .ignored)
        XCTAssertEqual(m.add(fix(lat: 0.01), isRecording: false), .ignored)
        XCTAssertEqual(m.distanceMeters, 0)
    }

    func testBadAccuracyIsIgnoredAndFlagged() {
        var m = RecorderMath()
        XCTAssertEqual(m.add(fix(hAcc: 50), isRecording: true), .ignored)
        XCTAssertTrue(m.isGPSDegraded)
        XCTAssertEqual(m.add(fix(hAcc: -1), isRecording: true), .ignored)
        XCTAssertTrue(m.isGPSDegraded)
        XCTAssertEqual(m.distanceMeters, 0)
    }

    func testAccuracyJustUnderTheLimitIsAccepted() {
        var m = RecorderMath()
        XCTAssertEqual(m.add(fix(hAcc: 49.9), isRecording: true), .accepted)
        XCTAssertFalse(m.isGPSDegraded)
    }

    func testDegradedFlagClearsWhenSignalReturns() {
        var m = RecorderMath()
        _ = m.add(fix(hAcc: 80), isRecording: true)
        XCTAssertTrue(m.isGPSDegraded)
        _ = m.add(fix(hAcc: 5), isRecording: true)
        XCTAssertFalse(m.isGPSDegraded)
    }

    func testDegradedFlagIsUpdatedEvenWhilePaused() {
        // The recorder shows the weak-signal warning even when not recording.
        var m = RecorderMath()
        _ = m.add(fix(hAcc: 80), isRecording: false)
        XCTAssertTrue(m.isGPSDegraded)
    }

    func testBadFixDoesNotBreakTheDistanceChain() {
        var m = RecorderMath()
        _ = m.add(fix(lat: 0.000), isRecording: true)
        _ = m.add(fix(lat: 0.500, hAcc: 90), isRecording: true)   // far away, but ignored
        _ = m.add(fix(lat: 0.001), isRecording: true)
        XCTAssertEqual(m.distanceMeters, 111.2, accuracy: 0.5)
    }

    func testSpeedAndMaxSpeed() {
        var m = RecorderMath()
        _ = m.add(fix(speed: 2.0), isRecording: true)
        _ = m.add(fix(speed: 5.5), isRecording: true)
        _ = m.add(fix(speed: 3.0), isRecording: true)
        XCTAssertEqual(m.currentSpeedMps, 3.0)
        XCTAssertEqual(m.maxSpeedMps, 5.5)
    }

    func testUnknownSpeedCountsAsZero() {
        var m = RecorderMath()
        _ = m.add(fix(speed: 4.0), isRecording: true)
        _ = m.add(fix(speed: -1), isRecording: true)
        XCTAssertEqual(m.currentSpeedMps, 0)
        XCTAssertEqual(m.maxSpeedMps, 4.0)
    }

    func testElevationGainCountsOnlyClimbs() {
        var m = RecorderMath()
        _ = m.add(fix(alt: 10), isRecording: true)
        _ = m.add(fix(alt: 15), isRecording: true)   // +5
        _ = m.add(fix(alt: 12), isRecording: true)   // down, ignored
        _ = m.add(fix(alt: 20), isRecording: true)   // +8 from 12
        XCTAssertEqual(m.elevationGainMeters, 13, accuracy: 0.001)
    }

    func testUntrustedAltitudeIsSkipped() {
        var m = RecorderMath()
        _ = m.add(fix(alt: 10), isRecording: true)
        _ = m.add(fix(alt: 500, vAcc: -1), isRecording: true)   // not trusted
        _ = m.add(fix(alt: 14), isRecording: true)              // +4 from 10
        XCTAssertEqual(m.elevationGainMeters, 4, accuracy: 0.001)
    }

    func testAFullRunWithAWeakPatch() {
        var m = RecorderMath()
        var accepted = 0
        for i in 0..<20 {
            let weak = (8...11).contains(i)
            let o = m.add(
                fix(lat: Double(i) * 0.0005, alt: 10 + Double(i % 4), hAcc: weak ? 120 : 6, speed: 3.2),
                isRecording: true
            )
            if o == .accepted { accepted += 1 }
        }
        XCTAssertEqual(accepted, 16)
        XCTAssertFalse(m.isGPSDegraded)               // the last fix was good
        XCTAssertGreaterThan(m.distanceMeters, 500)   // roughly 16 steps over a bit more than 0.0005 deg
        XCTAssertEqual(m.maxSpeedMps, 3.2)
    }
}
