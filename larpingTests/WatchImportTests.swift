import XCTest
@testable import larping

final class WatchImportTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(distance: Double = 1234.6, duration: Int = 600) -> WatchActivityRecord {
        WatchActivityRecord(
            id: UUID(), sport: .run, startedAt: t0, endedAt: t0.addingTimeInterval(Double(duration)),
            durationSeconds: duration, distanceMeters: distance, elevationGainMeters: 12.7,
            maxSpeedMps: 4.5,
            points: [WatchTrackPoint(timestamp: t0, latitude: 51.55, longitude: -0.28,
                                     altitudeMeters: 30, speedMps: 3, heartRateBpm: 150)])
    }

    func testValuesCarryEverythingAcross() throws {
        let v = try XCTUnwrap(WatchImport.values(from: record()))
        XCTAssertEqual(v.sportType, .run)
        XCTAssertEqual(v.distanceMeters, 1234)
        XCTAssertEqual(v.elevationGainMeters, 12)
        XCTAssertEqual(v.durationSeconds, 600)
        XCTAssertEqual(try XCTUnwrap(v.averageSpeedMps), 1234.6 / 600, accuracy: 0.001)
        XCTAssertEqual(v.maxSpeedMps, 4.5)
        XCTAssertEqual(v.trackPoints.count, 1)
        XCTAssertEqual(v.trackPoints[0].heartRateBpm, 150)
        XCTAssertEqual(v.trackPoints[0].latitude, 51.55)
        XCTAssertNotNil(ISO8601DateFormatter().date(from: v.trackPoints[0].timestamp))
    }

    func testEmptyNumbersBecomeNil() throws {
        var r = record(duration: 0)
        r.elevationGainMeters = 0
        r.maxSpeedMps = 0
        let v = try XCTUnwrap(WatchImport.values(from: r))
        XCTAssertNil(v.durationSeconds)
        XCTAssertNil(v.averageSpeedMps)
        XCTAssertNil(v.elevationGainMeters)
        XCTAssertNil(v.maxSpeedMps)
    }

    func testDuplicateDetection() {
        let r = record()
        XCTAssertTrue(WatchImport.isDuplicate(r, existing: [(source: "watch", startedAt: t0.addingTimeInterval(0.4))]))
        XCTAssertFalse(WatchImport.isDuplicate(r, existing: [(source: "mobile", startedAt: t0)]))
        XCTAssertFalse(WatchImport.isDuplicate(r, existing: [(source: "watch", startedAt: t0.addingTimeInterval(30))]))
        XCTAssertFalse(WatchImport.isDuplicate(r, existing: []))
    }

    func testFileFormatRoundTrip() throws {
        let r = record()
        XCTAssertEqual(try WatchActivityRecord.decode(r.encoded()), r)
    }
}
