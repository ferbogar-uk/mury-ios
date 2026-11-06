import XCTest
@testable import larping

final class HeartRateZonesTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_793_793_600)

    private func zones(_ max: Int) -> HeartRateZones {
        HeartRateZones(maxBpm: max)!
    }

    /// One reading per `every` seconds, starting at `base`.
    private func samples(_ bpms: [Int], every: TimeInterval = 1) -> [HeartRateSample] {
        bpms.enumerated().map { index, bpm in
            HeartRateSample(timestamp: base.addingTimeInterval(Double(index) * every), bpm: bpm)
        }
    }

    // MARK: edges

    func testEdgesForMax185() {
        let z = zones(185)
        XCTAssertEqual(z.lowerEdge(of: .z1), 0)
        XCTAssertEqual(z.lowerEdge(of: .z2), 111)
        XCTAssertEqual(z.lowerEdge(of: .z3), 130) // 129.5 rounds up
        XCTAssertEqual(z.lowerEdge(of: .z4), 148)
        XCTAssertEqual(z.lowerEdge(of: .z5), 167) // 166.5 rounds up
    }

    func testEdgesForMax176() {
        let z = zones(176)
        XCTAssertEqual(z.lowerEdge(of: .z2), 106)
        XCTAssertEqual(z.lowerEdge(of: .z3), 123)
        XCTAssertEqual(z.lowerEdge(of: .z4), 141)
        XCTAssertEqual(z.lowerEdge(of: .z5), 158)
    }

    func testNoZonesWithoutAUsableMax() {
        XCTAssertNil(HeartRateZones(maxBpm: nil))
        XCTAssertNil(HeartRateZones(maxBpm: 0))
        XCTAssertNil(HeartRateZones(maxBpm: -5))
    }

    func testZoneForBpmAtTheEdges() {
        let z = zones(185)
        XCTAssertEqual(z.zone(for: 0), .z1)
        XCTAssertEqual(z.zone(for: 110), .z1)
        XCTAssertEqual(z.zone(for: 111), .z2)
        XCTAssertEqual(z.zone(for: 147), .z3)
        XCTAssertEqual(z.zone(for: 148), .z4)
        XCTAssertEqual(z.zone(for: 166), .z4)
        XCTAssertEqual(z.zone(for: 167), .z5)
        XCTAssertEqual(z.zone(for: 230), .z5)
    }

    func testRangeText() {
        let z = zones(185)
        XCTAssertEqual(z.rangeText(of: .z1), "under 111 bpm")
        XCTAssertEqual(z.rangeText(of: .z2), "111–130 bpm")
        XCTAssertEqual(z.rangeText(of: .z4), "148–167 bpm")
        XCTAssertEqual(z.rangeText(of: .z5), "167+ bpm")
    }

    // MARK: time in zones

    func testTimeInZonesCountsEachReadingUntilTheNext() {
        // 185: Z1 below 111, Z2 111-129, Z3 130-147, Z4 148-166, Z5 167+.
        // Readings: 100, 100, 120, 150, 170, 170 -> intervals 1s each from the first five.
        let result = zones(185).timeInZones(samples([100, 100, 120, 150, 170, 170]))
        XCTAssertEqual(result.map(\.zone), HeartRateZone.allCases)
        XCTAssertEqual(result.map(\.seconds), [2, 1, 0, 1, 1])
        XCTAssertEqual(result.map(\.fraction), [0.4, 0.2, 0, 0.2, 0.2])
    }

    func testTimeInZonesIgnoresLongGaps() {
        // A 10 minute gap (watch off) is dropped; only the 1 second intervals count.
        var list = samples([150, 150])
        list.append(HeartRateSample(timestamp: base.addingTimeInterval(600), bpm: 150))
        list.append(HeartRateSample(timestamp: base.addingTimeInterval(601), bpm: 150))
        let result = zones(185).timeInZones(list)
        XCTAssertEqual(result.map(\.seconds).reduce(0, +), 2)
        XCTAssertEqual(result[3].seconds, 2)
    }

    func testTimeInZonesSortsTheReadings() {
        let shuffled = Array(samples([100, 120, 150, 170]).reversed())
        let result = zones(185).timeInZones(shuffled)
        XCTAssertEqual(result.map(\.seconds), [1, 1, 0, 1, 0])
    }

    func testTimeInZonesWithNothingIsFiveEmptyZones() {
        for list in [[], samples([150])] {
            let result = zones(185).timeInZones(list)
            XCTAssertEqual(result.count, 5)
            XCTAssertEqual(result.map(\.seconds), [0, 0, 0, 0, 0])
            XCTAssertEqual(result.map(\.fraction), [0, 0, 0, 0, 0])
        }
    }

    func testFractionsAddUpToOne() {
        let result = zones(185).timeInZones(samples([90, 115, 135, 155, 175, 160, 140, 120, 100]))
        XCTAssertEqual(result.map(\.fraction).reduce(0, +), 1, accuracy: 0.000001)
    }

    // MARK: measured max

    private func entry(hr: Int?, source: String = "mobile") -> StatsEntry {
        StatsEntry(startedAt: base, sport: .run, distanceMeters: 5000, durationSeconds: 1800, maxHeartRateBpm: hr, source: source)
    }

    func testMeasuredMaxIsTheHighestRealReading() {
        let entries = [entry(hr: 160), entry(hr: 176), entry(hr: nil), entry(hr: 171, source: "healthkit_import")]
        XCTAssertEqual(HeartRateZones.measuredMaxBpm(in: entries), 176)
    }

    func testMeasuredMaxIgnoresSampleActivities() {
        let entries = [entry(hr: 190, source: StatsEntry.sampleSource), entry(hr: 150)]
        XCTAssertEqual(HeartRateZones.measuredMaxBpm(in: entries), 150)
    }

    func testMeasuredMaxIsNilWithoutReadings() {
        XCTAssertNil(HeartRateZones.measuredMaxBpm(in: []))
        XCTAssertNil(HeartRateZones.measuredMaxBpm(in: [entry(hr: nil), entry(hr: 0)]))
        XCTAssertNil(HeartRateZones.measuredMaxBpm(in: [entry(hr: 190, source: StatsEntry.sampleSource)]))
    }

    // MARK: graph series

    func testSeriesMeasuresSecondsFromTheOrigin() {
        let points = HeartRateSeries.points(from: samples([100, 120, 140], every: 10), origin: base)
        XCTAssertEqual(points.map(\.seconds), [0, 10, 20])
        XCTAssertEqual(points.map(\.bpm), [100, 120, 140])
    }

    func testSeriesAveragesLongRecordingsIntoBuckets() {
        let bpms = (0..<400).map { $0 < 200 ? 100 : 160 }
        let points = HeartRateSeries.points(from: samples(bpms), origin: base, maxPoints: 200)
        XCTAssertEqual(points.count, 200)
        XCTAssertEqual(points.first?.bpm, 100)
        XCTAssertEqual(points.last?.bpm, 160)
        // Each bucket holds two readings one second apart: the first sits at 0.5 s.
        XCTAssertEqual(points.first?.seconds ?? -1, 0.5, accuracy: 0.000001)
    }

    func testSeriesDropsZeroReadingsAndHandlesEmpty() {
        XCTAssertTrue(HeartRateSeries.points(from: [], origin: base).isEmpty)
        XCTAssertTrue(HeartRateSeries.points(from: samples([0, 0]), origin: base).isEmpty)
        XCTAssertEqual(HeartRateSeries.points(from: samples([0, 120]), origin: base).count, 1)
    }

    func testSeriesNeverStartsBeforeTheOrigin() {
        let early = [HeartRateSample(timestamp: base.addingTimeInterval(-5), bpm: 110)]
        XCTAssertEqual(HeartRateSeries.points(from: early, origin: base).first?.seconds, 0)
    }

    func testNearestPoint() {
        let points = HeartRateSeries.points(from: samples([100, 120, 140], every: 10), origin: base)
        XCTAssertEqual(HeartRateSeries.nearest(to: 14, in: points)?.bpm, 120)
        XCTAssertEqual(HeartRateSeries.nearest(to: 26, in: points)?.bpm, 140)
        XCTAssertEqual(HeartRateSeries.nearest(to: -3, in: points)?.bpm, 100)
        XCTAssertNil(HeartRateSeries.nearest(to: 5, in: []))
    }
}
