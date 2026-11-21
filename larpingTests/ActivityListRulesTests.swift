import XCTest
@testable import larping

final class ActivityListRulesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func entry(_ sport: SportType, km: Double = 0, minutes: Int = 0) -> StatsEntry {
        StatsEntry(startedAt: Date(timeIntervalSince1970: 1_800_000_000), sport: sport,
                   distanceMeters: km > 0 ? Int(km * 1000) : nil, durationSeconds: minutes * 60, maxHeartRateBpm: nil)
    }

    func testSportsMostUsedFirstThenAppOrder() {
        let entries = [entry(.strength), entry(.run), entry(.strength), entry(.walk), entry(.run), entry(.yoga)]
        // run and strength twice each: run comes first in the app's order; walk before yoga likewise.
        XCTAssertEqual(ActivityListRules.sports(in: entries), [.run, .strength, .walk, .yoga])
        XCTAssertEqual(ActivityListRules.sports(in: []), [])
    }

    func testFilter() {
        XCTAssertTrue(ActivityListRules.matches(entry(.run), sport: nil))
        XCTAssertTrue(ActivityListRules.matches(entry(.run), sport: .run))
        XCTAssertFalse(ActivityListRules.matches(entry(.run), sport: .walk))
    }

    func testMonthTotalIgnoresMissingValues() {
        let total = ActivityListRules.total([entry(.run, km: 8.42, minutes: 44), entry(.strength, minutes: 52)])
        XCTAssertEqual(total.count, 2)
        XCTAssertEqual(total.distanceMeters, 8420)
        XCTAssertEqual(total.durationSeconds, 96 * 60)
    }

    func testMonthTitleAddsYearOnlyForOtherYears() {
        let en = Locale(identifier: "en_GB")
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21))!
        let nov = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let oldOct = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        XCTAssertEqual(ActivityListRules.monthTitle(nov, now: now, calendar: calendar, locale: en), "November")
        XCTAssertEqual(ActivityListRules.monthTitle(oldOct, now: now, calendar: calendar, locale: en), "October 2025")
    }

    func testCountLabel() {
        XCTAssertEqual(ActivityListRules.countLabel(1), "1 activity")
        XCTAssertEqual(ActivityListRules.countLabel(9), "9 activities")
    }
}
