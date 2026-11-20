import XCTest
@testable import larping

final class UserProfileTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func days(_ n: Double) -> Date { now.addingTimeInterval(n * 86_400) }

    private func complete() -> UserProfile {
        UserProfile(birthDate: days(-365 * 30), sex: .female,
                    heightCm: ProfileValue(value: 170, source: .manual, updatedAt: days(-5)),
                    weightKg: ProfileValue(value: 65, source: .manual, updatedAt: days(-5)))
    }

    func testNewerHealthWeightBeatsOlderManual() {
        let merged = complete().merging(health: HealthProfileSnapshot(weightKg: 63, weightDate: days(-1)))
        XCTAssertEqual(merged.weightKg?.value, 63)
        XCTAssertEqual(merged.weightKg?.source, .health)
    }

    func testNewerManualWeightBeatsOlderHealth() {
        let merged = complete().merging(health: HealthProfileSnapshot(weightKg: 63, weightDate: days(-9)))
        XCTAssertEqual(merged.weightKg?.value, 65)
        XCTAssertEqual(merged.weightKg?.source, .manual)
    }

    func testHealthFillsOnlyMissingFields() {
        var profile = complete()
        profile.birthDate = nil
        let merged = profile.merging(health: HealthProfileSnapshot(birthDate: days(-100), sex: .male))
        XCTAssertEqual(merged.birthDate, days(-100))
        XCTAssertEqual(merged.sex, .female)
        XCTAssertEqual(merged.heightCm?.value, 170)
    }

    func testCompleteProfileHasNoIssues() {
        XCTAssertTrue(complete().validationIssues(now: now).isEmpty)
    }

    func testMissingFieldsAreIssues() {
        XCTAssertEqual(UserProfile().validationIssues(now: now).count, 4)
    }

    func testFutureBirthDateIsInvalid() {
        var profile = complete(); profile.birthDate = days(2)
        XCTAssertFalse(profile.validationIssues(now: now).isEmpty)
    }

    func testBirthDateOverOneHundredFiftyYearsIsInvalid() {
        var profile = complete(); profile.birthDate = days(-365.25 * 151)
        XCTAssertFalse(profile.validationIssues(now: now).isEmpty)
    }

    func testHeightOutOfRangeIsInvalid() {
        for bad in [0.0, 49.0, 301.0] {
            var profile = complete()
            profile.heightCm = ProfileValue(value: bad, source: .manual, updatedAt: now)
            XCTAssertFalse(profile.validationIssues(now: now).isEmpty, "height \(bad)")
        }
    }

    func testWeightOutOfRangeIsInvalid() {
        for bad in [0.0, 19.0, 401.0] {
            var profile = complete()
            profile.weightKg = ProfileValue(value: bad, source: .manual, updatedAt: now)
            XCTAssertFalse(profile.validationIssues(now: now).isEmpty, "weight \(bad)")
        }
    }

    func testAgeOnBirthdayAndDayBefore() {
        let cal = UserProfile.utcCalendar
        let birth = cal.date(from: DateComponents(year: 1990, month: 6, day: 15))!
        var profile = complete(); profile.birthDate = birth
        let onDay = cal.date(from: DateComponents(year: 2020, month: 6, day: 15))!
        let before = cal.date(from: DateComponents(year: 2020, month: 6, day: 14))!
        XCTAssertEqual(profile.age(now: onDay), 30)
        XCTAssertEqual(profile.age(now: before), 29)
    }

    func testStorageRoundTripAndEmptyDefaults() throws {
        let suite = "UserProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(ProfileStorage.load(defaults), UserProfile())
        var profile = complete(); profile.sports = [.run, .walk]; profile.goal = .stayHealthy; profile.level = .beginner
        ProfileStorage.save(profile, to: defaults)
        XCTAssertEqual(ProfileStorage.load(defaults), profile)
        defaults.set(Data("junk".utf8), forKey: ProfileStorage.key)
        XCTAssertEqual(ProfileStorage.load(defaults), UserProfile())
    }
}
