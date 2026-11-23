import XCTest
@testable import larping

final class ProfileSummaryTests: XCTestCase {
    func testInitials() {
        XCTAssertEqual(ProfileSummary.initials(from: "Ricardo Bueno"), "RB")
        XCTAssertEqual(ProfileSummary.initials(from: "  ricardo  "), "R")
        XCTAssertEqual(ProfileSummary.initials(from: "Ana Maria Costa"), "AM")
        XCTAssertEqual(ProfileSummary.initials(from: ""), "M")
        XCTAssertEqual(ProfileSummary.initials(from: "123 456"), "M")
    }

    func testTotals() {
        XCTAssertEqual(ProfileSummary.totalDistance(meters: 0), "0 km")
        XCTAssertEqual(ProfileSummary.totalDistance(meters: 12_340), "12.3 km")
        XCTAssertEqual(ProfileSummary.totalDistance(meters: 842_400), "842 km")
        XCTAssertEqual(ProfileSummary.totalTime(seconds: 0), "0 h")
        XCTAssertEqual(ProfileSummary.totalTime(seconds: 34_200), "9.5 h")
        XCTAssertEqual(ProfileSummary.totalTime(seconds: 345_600), "96 h")
    }

    func testBackupState() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_793_793_600)
        let day: TimeInterval = 86_400
        XCTAssertEqual(ProfileSummary.backupState(lastBackup: nil, now: now, calendar: calendar), .never)
        let recent = now.addingTimeInterval(-10 * day)
        XCTAssertEqual(ProfileSummary.backupState(lastBackup: recent, now: now, calendar: calendar), .recent(recent))
        let old = now.addingTimeInterval(-45 * day)
        XCTAssertEqual(ProfileSummary.backupState(lastBackup: old, now: now, calendar: calendar), .stale(old))
    }
}
