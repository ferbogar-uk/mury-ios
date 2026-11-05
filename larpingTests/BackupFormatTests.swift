import XCTest
@testable import larping

final class BackupFormatTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func point(id: UUID = UUID(), hr: Int? = nil) -> BackupTrackPoint {
        BackupTrackPoint(
            id: id, timestamp: t0, latitude: 51.5, longitude: -0.12,
            altitudeMeters: nil, speedMps: nil, heartRateBpm: hr, cadenceRpm: nil
        )
    }

    private func activity(id: UUID = UUID(), points: [BackupTrackPoint] = []) -> BackupActivity {
        BackupActivity(
            id: id, sportTypeRaw: "run", startedAt: t0, endedAt: nil, durationSeconds: nil,
            distanceMeters: 1000, elevationGainMeters: nil, averageSpeedMps: nil,
            maxSpeedMps: nil, source: "mobile", eventName: nil, createdAt: t0, trackPoints: points
        )
    }

    private func container(app: String = "Larping", _ activities: [BackupActivity]) -> BackupContainer {
        BackupContainer(app: app, version: 1, exportedAt: t0, activities: activities)
    }

    private func encoded(_ c: BackupContainer) throws -> Data { try JSONEncoder.pretty.encode(c) }

    // MARK: - Reading a file

    func testRoundTripKeepsEverything() throws {
        let original = container([activity(points: [point(hr: 142)])])
        let back = try BackupImportPlan.container(from: try encoded(original))
        XCTAssertEqual(back.app, "Larping")
        XCTAssertEqual(back.version, 1)
        XCTAssertEqual(back.activities.count, 1)
        XCTAssertEqual(back.activities.first?.id, original.activities.first?.id)
        XCTAssertEqual(back.activities.first?.trackPoints.first?.heartRateBpm, 142)
        XCTAssertEqual(back.activities.first?.startedAt, t0)
    }

    func testGarbageIsAnInvalidFile() {
        XCTAssertThrowsError(try BackupImportPlan.container(from: Data("not json".utf8))) {
            XCTAssertEqual($0 as? BackupError, .invalidFile)
        }
    }

    func testJSONOfAnotherShapeIsAnInvalidFile() throws {
        let other = try JSONEncoder().encode(["hello": "world"])
        XCTAssertThrowsError(try BackupImportPlan.container(from: other)) {
            XCTAssertEqual($0 as? BackupError, .invalidFile)
        }
    }

    func testABackupOfAnotherAppIsRefused() throws {
        let data = try encoded(container(app: "SomethingElse", [activity()]))
        XCTAssertThrowsError(try BackupImportPlan.container(from: data)) {
            XCTAssertEqual($0 as? BackupError, .notLarpingFile)
        }
    }

    func testEmptyBackupIsFine() throws {
        let back = try BackupImportPlan.container(from: try encoded(container([])))
        XCTAssertTrue(back.activities.isEmpty)
    }

    // MARK: - The written format (what another app would have to read)

    private func text(_ c: BackupContainer) throws -> String {
        String(decoding: try encoded(c), as: UTF8.self)
    }

    func testDatesAreIsoTextInUtcWithWholeSeconds() throws {
        let json = try text(container([activity()]))
        XCTAssertTrue(json.contains("\"startedAt\" : \"2023-11-14T22:13:20Z\""), json)
    }

    func testAFractionOfASecondIsNotWritten() throws {
        let fractional = Date(timeIntervalSince1970: 1_700_000_000.789)
        let a = BackupActivity(
            id: UUID(), sportTypeRaw: "run", startedAt: fractional, endedAt: nil, durationSeconds: nil,
            distanceMeters: nil, elevationGainMeters: nil, averageSpeedMps: nil, maxSpeedMps: nil,
            source: "mobile", eventName: nil, createdAt: t0, trackPoints: []
        )
        let json = try text(container([a]))
        XCTAssertTrue(json.contains("\"startedAt\" : \"2023-11-14T22:13:20Z\""), json)
        let back = try BackupImportPlan.container(from: try encoded(container([a])))
        XCTAssertEqual(back.activities.first?.startedAt, t0)
    }

    func testEmptyOptionalsAreLeftOutOfTheFile() throws {
        let json = try text(container([activity()]))
        XCTAssertFalse(json.contains("endedAt"), json)
        XCTAssertFalse(json.contains("eventName"), json)
        XCTAssertFalse(json.contains("null"), json)
        XCTAssertTrue(json.contains("distanceMeters"), json)
    }

    func testAMissingKeyAndANullAreReadTheSame() throws {
        let withNull = Data("""
        {"app":"Larping","version":1,"exportedAt":"2023-11-14T22:13:20Z","activities":[
        {"id":"\(UUID().uuidString)","sportTypeRaw":"run","startedAt":"2023-11-14T22:13:20Z",
         "endedAt":null,"source":"mobile","createdAt":"2023-11-14T22:13:20Z","trackPoints":[]}]}
        """.utf8)
        let back = try BackupImportPlan.container(from: withNull)
        XCTAssertNil(back.activities.first?.endedAt)
        XCTAssertNil(back.activities.first?.distanceMeters)
    }

    func testTheAppNameIsExactlyLarping() throws {
        XCTAssertTrue(try text(container([])).contains("\"app\" : \"Larping\""))
    }

    // MARK: - What gets imported

    func testNewActivitiesAreAllImportedInFileOrder() {
        let a = activity(), b = activity(), c = activity()
        let plan = BackupImportPlan.plan(for: container([a, b, c]), existingIDs: [])
        XCTAssertEqual(plan.toImport.map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(plan.skipped, 0)
    }

    func testAnExistingIdIsSkipped() {
        let a = activity(), b = activity()
        let plan = BackupImportPlan.plan(for: container([a, b]), existingIDs: [a.id])
        XCTAssertEqual(plan.toImport.map(\.id), [b.id])
        XCTAssertEqual(plan.skipped, 1)
    }

    func testReimportingTheSameFileImportsNothing() {
        let a = activity(), b = activity()
        let plan = BackupImportPlan.plan(for: container([a, b]), existingIDs: [a.id, b.id])
        XCTAssertTrue(plan.toImport.isEmpty)
        XCTAssertEqual(plan.skipped, 2)
    }

    func testAnIdRepeatedInsideOneFileIsImportedOnce() {
        let id = UUID()
        let plan = BackupImportPlan.plan(for: container([activity(id: id), activity(id: id)]), existingIDs: [])
        XCTAssertEqual(plan.toImport.count, 1)
        XCTAssertEqual(plan.skipped, 1)
    }

    func testTheFirstCopyOfARepeatedIdWins() {
        let id = UUID()
        let first = activity(id: id, points: [point(hr: 100)])
        let second = activity(id: id, points: [point(hr: 200)])
        let plan = BackupImportPlan.plan(for: container([first, second]), existingIDs: [])
        XCTAssertEqual(plan.toImport.first?.trackPoints.first?.heartRateBpm, 100)
    }

    func testAnEmptyFileImportsNothing() {
        let plan = BackupImportPlan.plan(for: container([]), existingIDs: [UUID()])
        XCTAssertTrue(plan.toImport.isEmpty)
        XCTAssertEqual(plan.skipped, 0)
    }
}