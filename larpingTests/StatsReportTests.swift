import XCTest
@testable import larping

final class StatsReportTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Wednesday 2026-11-04 12:00 UTC.
    private var now: Date { Date(timeIntervalSince1970: 1_793_793_600) }

    private func daysAgo(_ d: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -d, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: 9, to: day)!
    }

    private func entry(_ d: Int, _ sport: SportType = .run, dist: Int? = 5000, dur: Int? = 1800, source: String = "mobile") -> StatsEntry {
        StatsEntry(startedAt: daysAgo(d), sport: sport, distanceMeters: dist, durationSeconds: dur, maxHeartRateBpm: nil, source: source)
    }

    private func report(_ entries: [StatsEntry], _ period: StatsPeriod) -> StatsReport {
        StatsReport(entries: entries, period: period, now: now, calendar: calendar)
    }

    func testWeekMatchesSummaryRule() {
        let entries = [entry(0), entry(6), entry(7), entry(1, source: "sample"), StatsEntry(startedAt: now.addingTimeInterval(3600), sport: .run, distanceMeters: 9000, durationSeconds: 100, maxHeartRateBpm: nil)]
        let r = report(entries, .week)
        let s = StatsSummary(entries: entries, now: now, calendar: calendar)
        XCTAssertEqual(r.activityCount, 2)
        XCTAssertEqual(r.distanceMeters, s.weekDistance)
        XCTAssertEqual(r.durationSeconds, s.weekDuration)
        XCTAssertEqual(r.buckets.map(\.distanceMeters), s.dailyDistance.map(\.distanceMeters))
        XCTAssertEqual(r.bucketUnit, .day)
    }

    func testChangeComparesWithThePreviousSevenDays() {
        // This week 10 km, the 7 days before 8 km: +25 percent.
        let r = report([entry(0, dist: 10_000), entry(8, dist: 8000)], .week)
        XCTAssertEqual(r.distanceChangePercent, 25)
        XCTAssertEqual(report([entry(0, dist: 4000), entry(9, dist: 8000)], .week).distanceChangePercent, -50)
    }

    func testNoChangeWithoutAnEarlierPeriodOrForAll() {
        XCTAssertNil(report([entry(0)], .week).distanceChangePercent)
        XCTAssertNil(report([entry(0), entry(8)], .all).distanceChangePercent)
    }

    func testMonthIsThirtyDaysWithThirtyBars() {
        let r = report([entry(0), entry(29), entry(30)], .month)
        XCTAssertEqual(r.activityCount, 2)
        XCTAssertEqual(r.buckets.count, 30)
        XCTAssertEqual(r.distanceChangePercent, 100)
    }

    func testYearHasTwelveMonthBarsEndingThisMonth() {
        let longAgo = StatsEntry(startedAt: calendar.date(byAdding: .month, value: -14, to: now)!, sport: .run, distanceMeters: 7000, durationSeconds: 100, maxHeartRateBpm: nil)
        let r = report([entry(0), entry(40), longAgo], .year)
        XCTAssertEqual(r.bucketUnit, .month)
        XCTAssertEqual(r.buckets.count, 12)
        XCTAssertEqual(r.activityCount, 2)
        XCTAssertEqual(r.buckets.last?.distanceMeters, 5000)
        XCTAssertEqual(r.buckets.map(\.distanceMeters).reduce(0, +), 10_000)
    }

    func testAllUsesMonthsUnderAYearAndYearsAfter() {
        let young = report([entry(0), entry(70)], .all)
        XCTAssertEqual(young.bucketUnit, .month)
        XCTAssertEqual(young.buckets.count, 4)
        let oldEntry = StatsEntry(startedAt: calendar.date(byAdding: .year, value: -2, to: now)!, sport: .run, distanceMeters: 3000, durationSeconds: 100, maxHeartRateBpm: nil)
        let old = report([entry(0), oldEntry], .all)
        XCTAssertEqual(old.bucketUnit, .year)
        XCTAssertEqual(old.buckets.count, 3)
        XCTAssertEqual(old.buckets.map(\.distanceMeters).reduce(0, +), 8000)
    }

    func testAllWithNoActivitiesHasOneEmptyMonth() {
        let r = report([], .all)
        XCTAssertEqual(r.buckets.count, 1)
        XCTAssertEqual(r.distanceMeters, 0)
        XCTAssertNil(r.averagePaceSecondsPerKm)
    }

    func testAveragePaceOnlyCountsPaceSports() {
        // 5 km in 1800 s = 360 s/km; the ride is ignored.
        let r = report([entry(0, .run, dist: 5000, dur: 1800), entry(1, .ride, dist: 40_000, dur: 3600)], .week)
        XCTAssertEqual(r.averagePaceSecondsPerKm, 360)
        XCTAssertEqual(r.distanceMeters, 45_000)
        XCTAssertNil(report([entry(0, .ride)], .week).averagePaceSecondsPerKm)
    }

    func testBySportSortedByDistance() {
        let r = report([entry(0, .walk, dist: 2000), entry(1, .run, dist: 9000), entry(2, .strength, dist: nil, dur: 3000)], .week)
        XCTAssertEqual(r.bySport.map(\.sport), [.run, .walk, .strength])
    }
}
