import Foundation
import XCTest
@testable import larping

@MainActor
final class HomeSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/London")!
        return value
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func activity(_ startedAt: Date, source: String = "mobile", distance: Int? = 1000, duration: Int? = 300) -> CDActivity {
        let activity = CDActivity()
        activity.startedAt = startedAt
        activity.source = source
        activity.distanceMeters = distance
        activity.durationSeconds = duration
        return activity
    }

    func testNoDataAndSamplesHaveNoPersonalSummary() {
        let now = date("2026-10-30T12:00:00Z")
        for activities in [[], [activity(now, source: "sample")]] {
            let summary = HomeSummary(activities: activities, now: now, calendar: calendar)
            XCTAssertEqual(summary.weeklyDistanceMeters, 0)
            XCTAssertEqual(summary.weeklyDurationSeconds, 0)
            XCTAssertEqual(summary.weeklyCount, 0)
            XCTAssertTrue(summary.recentActivities.isEmpty)
        }
    }

    func testInclusiveCalendarBoundsAndFutureExcludedEverywhere() {
        let now = date("2026-10-30T12:00:00Z")
        // London midnight is still BST on Oct 24, before the Oct 25 DST change.
        let lower = date("2026-10-23T23:00:00Z")
        let before = activity(lower.addingTimeInterval(-1))
        let atLower = activity(lower)
        let atNow = activity(now)
        let future = activity(now.addingTimeInterval(1))
        let summary = HomeSummary(activities: [future, before, atLower, atNow], now: now, calendar: calendar)
        XCTAssertEqual(calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)), lower)
        XCTAssertEqual(summary.weeklyCount, 2)
        XCTAssertEqual(summary.weeklyDistanceMeters, 2000)
        XCTAssertEqual(summary.weeklyDurationSeconds, 600)
        XCTAssertEqual(summary.recentActivities.map(\.id), [atNow.id, atLower.id, before.id])
    }

    func testCalendarDayRolloverExpiresOldestDayFromWeeklyTotals() {
        let beforeMidnight = date("2026-10-30T23:59:59Z")
        let afterMidnight = date("2026-10-31T00:00:00Z")
        let expired = activity(date("2026-10-23T23:00:00Z"), distance: 1000, duration: 300)
        let retained = activity(date("2026-10-25T12:00:00Z"), distance: 2000, duration: 600)
        let activities = [expired, retained]

        let before = HomeSummary(activities: activities, now: beforeMidnight, calendar: calendar)
        XCTAssertEqual(before.weeklyCount, 2)
        XCTAssertEqual(before.weeklyDistanceMeters, 3000)
        XCTAssertEqual(before.weeklyDurationSeconds, 900)

        let after = HomeSummary(activities: activities, now: afterMidnight, calendar: calendar)
        XCTAssertEqual(after.weeklyCount, 1)
        XCTAssertEqual(after.weeklyDistanceMeters, 2000)
        XCTAssertEqual(after.weeklyDurationSeconds, 600)
        XCTAssertEqual(after.recentActivities.map(\.id), [retained.id, expired.id])
    }

    func testImportsAndNilMetricsCountWithoutInventingMetrics() {
        let now = date("2026-10-30T12:00:00Z")
        let activities = [
            activity(now, source: "gpx_import", distance: nil, duration: 120),
            activity(now, source: "healthkit_import", distance: 2000, duration: nil),
            activity(now, distance: nil, duration: nil),
            activity(now, source: "sample", distance: 99999, duration: 99999)
        ]
        let summary = HomeSummary(activities: activities, now: now, calendar: calendar)
        XCTAssertEqual(summary.weeklyCount, 3)
        XCTAssertEqual(summary.weeklyDistanceMeters, 2000)
        XCTAssertEqual(summary.weeklyDurationSeconds, 120)
        XCTAssertEqual(Set(summary.recentActivities.map(\.source)), Set(["mobile", "gpx_import", "healthkit_import"]))
    }

    func testRecentUsesNewestThreeIncludingOldRealActivitiesWithoutMutatingInput() {
        let now = date("2026-10-30T12:00:00Z")
        let old = activity(date("2026-09-01T12:00:00Z"))
        let newest = activity(now, source: "gpx_import")
        let middle = activity(date("2026-10-29T12:00:00Z"), source: "healthkit_import")
        let oldest = activity(date("2026-08-01T12:00:00Z"))
        let sample = activity(now, source: "sample")
        let future = activity(now.addingTimeInterval(1))
        let activities = [old, sample, oldest, newest, future, middle]
        let ids = activities.map(\.id)
        let dates = activities.map(\.startedAt)
        let sources = activities.map(\.source)
        let distances = activities.map(\.distanceMeters)
        let durations = activities.map(\.durationSeconds)
        let summary = HomeSummary(activities: activities, now: now, calendar: calendar)
        XCTAssertEqual(summary.weeklyCount, 2)
        XCTAssertEqual(summary.recentActivities.map(\.id), [newest.id, middle.id, old.id])
        XCTAssertEqual(activities.map(\.id), ids)
        XCTAssertEqual(activities.map(\.startedAt), dates)
        XCTAssertEqual(activities.map(\.source), sources)
        XCTAssertEqual(activities.map(\.distanceMeters), distances)
        XCTAssertEqual(activities.map(\.durationSeconds), durations)
    }

    func testShortcutCanRepeatSportAfterMenuSelection() {
        var requests = RecordSportRequestState()
        let first = UUID()
        XCTAssertEqual(requests.consume(sport: .ride, requestID: first, isIdle: true), .ride)
        XCTAssertNil(requests.consume(sport: .ride, requestID: first, isIdle: true))
        // A menu change doesn't alter the last Home request; a new ID selects Ride again.
        XCTAssertEqual(requests.consume(sport: .ride, requestID: UUID(), isIdle: true), .ride)
    }

    func testIgnoredActiveAndPausedRequestsNeverApplyAfterFinish() {
        for sport in [SportType.ride, .swim] {
            var requests = RecordSportRequestState()
            let requestID = UUID()
            XCTAssertNil(requests.consume(sport: sport, requestID: requestID, isIdle: false))
            XCTAssertNil(requests.consume(sport: sport, requestID: requestID, isIdle: true))
            XCTAssertEqual(requests.consume(sport: sport, requestID: UUID(), isIdle: true), sport)
        }
    }

    func testDefaultCallerAndChangedInitialSportAreConsumedOnce() {
        var requests = RecordSportRequestState()
        XCTAssertEqual(requests.consume(sport: .run, requestID: nil, isIdle: true), .run)
        XCTAssertNil(requests.consume(sport: .run, requestID: nil, isIdle: true))
        XCTAssertEqual(requests.consume(sport: .walk, requestID: nil, isIdle: true), .walk)
    }
}
