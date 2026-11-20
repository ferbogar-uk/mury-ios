import XCTest
@testable import larping

final class HealthImportRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ id: String = "A", daysAgo: Double = 3, duration: Int = 1800, mury: Bool = false) -> HealthWorkoutRecord {
        let start = now.addingTimeInterval(-daysAgo * 86_400)
        return HealthWorkoutRecord(externalID: id, startedAt: start,
                                   endedAt: start.addingTimeInterval(Double(duration)),
                                   durationSeconds: duration, writtenByMury: mury)
    }

    func testKeepsRecentNewWorkout() {
        XCTAssertEqual(HealthImportRules.select([record()], existing: [], now: now).count, 1)
    }

    func testSkipsOlderThanNinetyDays() {
        XCTAssertTrue(HealthImportRules.select([record(daysAgo: 91)], existing: [], now: now).isEmpty)
        XCTAssertEqual(HealthImportRules.select([record(daysAgo: 89)], existing: [], now: now).count, 1)
    }

    func testSkipsMuryOwnWorkouts() {
        XCTAssertTrue(HealthImportRules.select([record(mury: true)], existing: [], now: now).isEmpty)
    }

    func testSkipsZeroDuration() {
        XCTAssertTrue(HealthImportRules.select([record(duration: 0)], existing: [], now: now).isEmpty)
    }

    func testSkipsSameExternalID() {
        let existing = [ExistingImport(externalID: "A", startedAt: now.addingTimeInterval(-10 * 86_400))]
        XCTAssertTrue(HealthImportRules.select([record("A")], existing: existing, now: now).isEmpty)
    }

    func testSkipsEarlierManualImportByStartTime() {
        let r = record()
        let near = ExistingImport(externalID: nil, startedAt: r.startedAt.addingTimeInterval(59))
        let far = ExistingImport(externalID: nil, startedAt: r.startedAt.addingTimeInterval(61))
        XCTAssertTrue(HealthImportRules.select([r], existing: [near], now: now).isEmpty)
        XCTAssertEqual(HealthImportRules.select([r], existing: [far], now: now).count, 1)
    }

    func testSecondRunImportsNothing() {
        let records = [record("A", daysAgo: 5), record("B", daysAgo: 2)]
        let first = HealthImportRules.select(records, existing: [], now: now)
        XCTAssertEqual(first.count, 2)
        let existing = first.map { ExistingImport(externalID: $0.externalID, startedAt: $0.startedAt) }
        XCTAssertTrue(HealthImportRules.select(records, existing: existing, now: now).isEmpty)
    }

    func testResultIsOldestFirst() {
        let result = HealthImportRules.select(
            [record("C", daysAgo: 1), record("A", daysAgo: 9), record("B", daysAgo: 4)], existing: [], now: now)
        XCTAssertEqual(result.map(\.externalID), ["A", "B", "C"])
    }

    func testSyncThrottle() {
        XCTAssertTrue(HealthImportRules.shouldSync(last: nil, now: now))
        XCTAssertFalse(HealthImportRules.shouldSync(last: now.addingTimeInterval(-599), now: now))
        XCTAssertTrue(HealthImportRules.shouldSync(last: now.addingTimeInterval(-600), now: now))
    }
}
