import XCTest
@testable import larping

final class StatsSummaryTests: XCTestCase {
    /// A fixed calendar and "now", so results never depend on the day tests run.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Wednesday 2026-11-04 12:00 UTC.
    private var now: Date { Date(timeIntervalSince1970: 1_793_793_600) }

    private func daysAgo(_ d: Int, hour: Int = 9) -> Date {
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: -d, to: today)!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private func entry(
        _ d: Int, _ sport: SportType = .run, dist: Int? = 5000, dur: Int? = 1800, hr: Int? = nil
    ) -> StatsEntry {
        StatsEntry(startedAt: daysAgo(d), sport: sport, distanceMeters: dist, durationSeconds: dur, maxHeartRateBpm: hr)
    }

    private func summary(_ entries: [StatsEntry]) -> StatsSummary {
        StatsSummary(entries: entries, now: now, calendar: calendar)
    }

    func testEmptyIsAllZero() {
        let s = summary([])
        XCTAssertEqual(s.lastWeek.count, 0)
        XCTAssertEqual(s.allTimeCount, 0)
        XCTAssertEqual(s.weekDistance, 0)
        XCTAssertNil(s.longestDistance)
        XCTAssertEqual(s.dailyDistance.count, 7)
        XCTAssertTrue(s.bySport.isEmpty)
    }

    func testWeekWindowIsTodayAndTheSixDaysBefore() {
        // 0..6 days ago are inside; 7 days ago is outside.
        let s = summary([entry(0), entry(6), entry(7), entry(30)])
        XCTAssertEqual(s.lastWeek.count, 2)
        XCTAssertEqual(s.allTimeCount, 4)
    }

    func testWeekTotalsVersusAllTimeTotals() {
        let s = summary([entry(1, dist: 10_000, dur: 3000), entry(2, dist: 4000, dur: 1000), entry(20, dist: 21_000, dur: 7000)])
        XCTAssertEqual(s.weekDistance, 14_000)
        XCTAssertEqual(s.weekDuration, 4000)
        XCTAssertEqual(s.allTimeDistance, 35_000)
        XCTAssertEqual(s.allTimeDuration, 11_000)
    }

    func testMissingDistanceAndDurationCountAsZero() {
        let s = summary([entry(1, dist: nil, dur: nil), entry(1, dist: 1000, dur: 60)])
        XCTAssertEqual(s.weekDistance, 1000)
        XCTAssertEqual(s.weekDuration, 60)
        XCTAssertEqual(s.lastWeek.count, 2)
    }

    func testDailyDistanceHasSevenDaysOldestFirstAndSumsPerDay() {
        let s = summary([entry(0, dist: 3000), entry(0, dist: 2000), entry(2, dist: 8000)])
        XCTAssertEqual(s.dailyDistance.count, 7)
        XCTAssertEqual(s.dailyDistance.first?.day, daysAgo(6, hour: 0))
        XCTAssertEqual(s.dailyDistance.last?.day, daysAgo(0, hour: 0))
        XCTAssertEqual(s.dailyDistance.last?.distanceMeters, 5000)
        XCTAssertEqual(s.dailyDistance[4].distanceMeters, 8000)   // 2 days ago
        XCTAssertEqual(s.dailyDistance[5].distanceMeters, 0)      // yesterday
    }

    func testBySportIsGroupedAndSortedByDistance() {
        let s = summary([
            entry(1, .run, dist: 5000, dur: 1500), entry(2, .run, dist: 5000, dur: 1500),
            entry(1, .ride, dist: 30_000, dur: 3600), entry(3, .walk, dist: 2000, dur: 1200),
        ])
        XCTAssertEqual(s.bySport.map(\.sport), [.ride, .run, .walk])
        let run = s.bySport.first { $0.sport == .run }!
        XCTAssertEqual(run.distanceMeters, 10_000)
        XCTAssertEqual(run.durationSeconds, 3000)
        XCTAssertEqual(run.count, 2)
    }

    func testBySportMaxHeartRateIsTheHighestAndNilWhenNone() {
        let s = summary([entry(1, .run, hr: 150), entry(2, .run, hr: 178), entry(1, .ride, hr: nil)])
        XCTAssertEqual(s.bySport.first { $0.sport == .run }?.maxHeartRateBpm, 178)
        XCTAssertNil(s.bySport.first { $0.sport == .ride }?.maxHeartRateBpm)
    }

    func testPersonalBestsLookAtAllTimeNotJustTheWeek() {
        let old = entry(40, .ride, dist: 90_000, dur: 14_400, hr: 190)
        let s = summary([entry(1, .run, dist: 5000, dur: 1500, hr: 160), old])
        XCTAssertEqual(s.longestDistance, old)
        XCTAssertEqual(s.longestDuration, old)
        XCTAssertEqual(s.highestHeartRate, old)
    }

    func testStatsEntriesFromDifferentTimesOfDayLandOnTheirOwnDay() {
        let late = StatsEntry(startedAt: calendar.date(byAdding: .hour, value: 23, to: calendar.startOfDay(for: now))!,
                              sport: .run, distanceMeters: 1000, durationSeconds: 60, maxHeartRateBpm: nil)
        let s = summary([late])
        XCTAssertEqual(s.dailyDistance.last?.distanceMeters, 1000)
    }
}
