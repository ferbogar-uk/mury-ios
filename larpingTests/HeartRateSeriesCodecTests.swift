import XCTest
@testable import larping

final class HeartRateSeriesCodecTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testRoundTripSortedAndValidOnly() {
        let samples = [
            HeartRateSample(timestamp: t0.addingTimeInterval(10), bpm: 130),
            HeartRateSample(timestamp: t0, bpm: 120),
            HeartRateSample(timestamp: t0.addingTimeInterval(5), bpm: 0),
        ]
        let decoded = HeartRateSeriesCodec.decode(HeartRateSeriesCodec.encode(samples))
        XCTAssertEqual(decoded, [
            HeartRateSample(timestamp: t0, bpm: 120),
            HeartRateSample(timestamp: t0.addingTimeInterval(10), bpm: 130),
        ])
    }

    func testEmptyGivesNoData() {
        XCTAssertNil(HeartRateSeriesCodec.encode([]))
        XCTAssertNil(HeartRateSeriesCodec.encode([HeartRateSample(timestamp: t0, bpm: 0)]))
    }

    func testBadDataGivesNoSamples() {
        XCTAssertTrue(HeartRateSeriesCodec.decode(nil).isEmpty)
        XCTAssertTrue(HeartRateSeriesCodec.decode(Data("nope".utf8)).isEmpty)
        XCTAssertEqual(HeartRateSeriesCodec.decode(Data("[[1,2,3],[1800000000,150]]".utf8)).count, 1)
    }

    func testOldBackupWithoutNewFieldsStillDecodes() throws {
        let json = #"{"id":"6F1C2C1E-1111-4C2B-9C1A-000000000001","sportTypeRaw":"run","startedAt":0,"source":"mobile","createdAt":0,"trackPoints":[]}"#
        let activity = try JSONDecoder().decode(BackupActivity.self, from: Data(json.utf8))
        XCTAssertNil(activity.heartRateSeriesData)
        XCTAssertNil(activity.energyKcal)
    }
}
