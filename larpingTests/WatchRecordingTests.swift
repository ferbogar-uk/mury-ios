import XCTest
@testable import larping

final class WatchRecordingTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func fix(lat: Double, hAcc: Double = 5, speed: Double = 3) -> GPSFix {
        GPSFix(latitude: lat, longitude: 0, altitude: 10, horizontalAccuracy: hAcc,
               verticalAccuracy: 5, speed: speed)
    }

    func testSportRawValuesMatchTheiPhone() {
        for sport in WatchSport.allCases {
            let phone = SportType(rawValue: sport.rawValue)
            XCTAssertNotNil(phone, sport.rawValue)
            XCTAssertEqual(phone?.label, sport.label)
            XCTAssertEqual(phone?.usesPaceMetric, sport.usesPace)
        }
    }

    func testElapsedExcludesPauses() {
        var core = WatchRecorderCore()
        core.start(sport: .run, at: t0)
        core.pause(at: t0.addingTimeInterval(60))
        XCTAssertEqual(core.elapsedSeconds(at: t0.addingTimeInterval(500)), 60)
        core.resume(at: t0.addingTimeInterval(600))
        XCTAssertEqual(core.elapsedSeconds(at: t0.addingTimeInterval(630)), 90)
    }

    func testPointsAreKeptOnlyWhileRecording() {
        var core = WatchRecorderCore()
        core.start(sport: .run, at: t0)
        XCTAssertFalse(core.hasFix)
        XCTAssertTrue(core.add(fix(lat: 0), at: t0, heartRate: 120))
        XCTAssertTrue(core.hasFix)
        core.pause(at: t0.addingTimeInterval(5))
        XCTAssertFalse(core.add(fix(lat: 0.001), at: t0.addingTimeInterval(6), heartRate: nil))
        core.resume(at: t0.addingTimeInterval(10))
        XCTAssertTrue(core.add(fix(lat: 0.002), at: t0.addingTimeInterval(11), heartRate: 130))
        XCTAssertEqual(core.points.count, 2)
    }

    func testWeakSignalIsDroppedAndFlagged() {
        var core = WatchRecorderCore()
        core.start(sport: .run, at: t0)
        XCTAssertFalse(core.add(fix(lat: 0, hAcc: 80), at: t0, heartRate: nil))
        XCTAssertTrue(core.isGPSDegraded)
        XCTAssertFalse(core.hasFix)
    }

    func testFinishBuildsRecordAndResets() throws {
        var core = WatchRecorderCore()
        core.start(sport: .ride, at: t0)
        core.add(fix(lat: 0.000), at: t0, heartRate: 100)
        core.add(fix(lat: 0.001, speed: 7), at: t0.addingTimeInterval(20), heartRate: 150)
        let id = UUID()
        let record = try XCTUnwrap(core.finish(at: t0.addingTimeInterval(30), id: id))
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.sport, .ride)
        XCTAssertEqual(record.durationSeconds, 30)
        XCTAssertEqual(record.distanceMeters, 110.57, accuracy: 0.2)
        XCTAssertEqual(record.maxSpeedMps, 7)
        XCTAssertEqual(record.points.map(\.heartRateBpm), [100, 150])
        XCTAssertEqual(core.state, .idle)
        XCTAssertNil(core.finish(at: t0))
    }

    func testTooShortRule() {
        let base = WatchActivityRecord(
            id: UUID(), sport: .run, startedAt: t0, endedAt: t0, durationSeconds: 5,
            distanceMeters: 3, elevationGainMeters: 0, maxSpeedMps: 0, points: [])
        XCTAssertTrue(base.isTooShort)
        var longer = base
        longer.durationSeconds = 30
        XCTAssertFalse(longer.isTooShort)
        var farther = base
        farther.distanceMeters = 50
        XCTAssertFalse(farther.isTooShort)
    }

    func testSnapshotReusesMirrorFormatting() {
        var core = WatchRecorderCore()
        core.start(sport: .walk, at: t0)
        let snapshot = core.snapshot(at: t0.addingTimeInterval(75))
        XCTAssertEqual(snapshot.state, .recording)
        XCTAssertEqual(MirrorDisplay(snapshot).time, "1:15")
        XCTAssertEqual(snapshot.sportLabel, "Walk")
        XCTAssertEqual(WatchRecorderCore.State.paused.mirrored, .paused)
    }

    func testStoreRoundTripOrderAndDelete() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = WatchActivityStore(directory: dir)
        XCTAssertTrue(store.loadAll().isEmpty)

        func record(_ offset: TimeInterval) -> WatchActivityRecord {
            WatchActivityRecord(
                id: UUID(), sport: .run, startedAt: t0.addingTimeInterval(offset),
                endedAt: t0.addingTimeInterval(offset + 60), durationSeconds: 60,
                distanceMeters: 200, elevationGainMeters: 1, maxSpeedMps: 4,
                points: [WatchTrackPoint(timestamp: t0, latitude: 51.5, longitude: -0.28,
                                         altitudeMeters: 30, speedMps: 3, heartRateBpm: 140)])
        }
        let later = record(1000), earlier = record(0)
        try store.save(later)
        try store.save(earlier)
        XCTAssertEqual(store.loadAll(), [earlier, later])

        store.delete(id: earlier.id)
        XCTAssertEqual(store.loadAll(), [later])

        try Data("not json".utf8).write(to: dir.appendingPathComponent("broken.json"))
        XCTAssertEqual(store.loadAll(), [later])
    }
}
