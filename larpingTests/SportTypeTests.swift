import XCTest
@testable import larping

final class SportTypeTests: XCTestCase {
    func testTwentyTwoTypesWithUniqueLabelsAndIcons() {
        XCTAssertEqual(SportType.allCases.count, 22)
        XCTAssertEqual(Set(SportType.allCases.map(\.label)).count, 22)
        XCTAssertEqual(Set(SportType.allCases.map(\.rawValue)).count, 22)
        XCTAssertTrue(SportType.allCases.allSatisfy { $0.symbolName.hasPrefix("figure.") })
    }

    func testStoredRawValuesNeverChange() {
        // Saved activities and backups hold these strings.
        for raw in ["run", "ride", "walk", "hike", "swim", "other"] {
            XCTAssertNotNil(SportType(rawValue: raw), raw)
        }
        XCTAssertEqual(SportType.indoorCycle.rawValue, "indoorCycle")
    }

    func testIndoorTypesAreNotRecordableYet() {
        XCTAssertTrue(SportType.strength.isIndoor)
        XCTAssertTrue(SportType.treadmill.isIndoor)
        XCTAssertFalse(SportType.run.isIndoor)
        XCTAssertFalse(SportType.other.isIndoor)
        XCTAssertEqual(SportType.recordable,
                       [.run, .walk, .hike, .ride, .swim, .rowing, .tennis, .football, .other])
        XCTAssertEqual(SportType.allCases.filter(\.isIndoor).count, 13)
    }

    func testPaceOrSpeed() {
        XCTAssertTrue(SportType.treadmill.usesPaceMetric)
        XCTAssertTrue(SportType.run.usesPaceMetric)
        XCTAssertFalse(SportType.indoorCycle.usesPaceMetric)
        XCTAssertFalse(SportType.strength.usesPaceMetric)
    }

    func testDecodingOldBackupValue() throws {
        let decoded = try JSONDecoder().decode([SportType].self, from: Data(#"["run","other","strength"]"#.utf8))
        XCTAssertEqual(decoded, [.run, .other, .strength])
    }

    func testHealthReclassifyRule() {
        let id = UUID().uuidString
        XCTAssertTrue(HealthImportRules.needsReclassifying(sport: .other, source: "healthkit_import", externalID: id))
        XCTAssertFalse(HealthImportRules.needsReclassifying(sport: .run, source: "healthkit_import", externalID: id))
        XCTAssertFalse(HealthImportRules.needsReclassifying(sport: .other, source: "mobile", externalID: id))
        XCTAssertFalse(HealthImportRules.needsReclassifying(sport: .other, source: "healthkit_import", externalID: nil))
        XCTAssertFalse(HealthImportRules.needsReclassifying(sport: .other, source: "healthkit_import", externalID: "x"))
    }

    func testPortugueseTitlesForNewTypes() {
        XCTAssertEqual(ActivityNamer.noun(for: .strength), "Musculação")
        XCTAssertEqual(ActivityNamer.noun(for: .treadmill), "Passadeira")
    }

    func testGPXRowing() {
        XCTAssertEqual(GPXParser.sportType(from: "Rowing"), .rowing)
        XCTAssertEqual(GPXParser.sportType(from: "running"), .run)
    }
}
