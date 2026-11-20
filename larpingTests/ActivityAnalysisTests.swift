import XCTest
@testable import larping

final class ActivityAnalysisTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Points due north from the equator, 0.001° apart (about 110.6 m), 30 s apart.
    private func line(_ count: Int, altitude: ((Int) -> Double?)? = nil) -> [AnalysisPoint] {
        (0..<count).map { i in
            AnalysisPoint(timestamp: start.addingTimeInterval(Double(i) * 30),
                          latitude: Double(i) * 0.001, longitude: 0,
                          altitudeMeters: altitude?(i))
        }
    }

    private var stepMeters: Double {
        GeoDistance.meters(fromLatitude: 0, longitude: 0, toLatitude: 0.001, longitude: 0)
    }

    func testNoSplitsWithoutTwoPoints() {
        XCTAssertTrue(ActivityAnalysis.splits([]).isEmpty)
        XCTAssertTrue(ActivityAnalysis.splits(line(1)).isEmpty)
    }

    func testFullKilometresAndPartialRest() {
        let points = line(25) // 24 steps, about 2.65 km
        let splits = ActivityAnalysis.splits(points)
        let total = stepMeters * 24
        XCTAssertEqual(splits.count, 3)
        XCTAssertEqual(splits.map(\.index), [1, 2, 3])
        let expectedFull = 1000 / stepMeters * 30
        XCTAssertEqual(splits[0].seconds, expectedFull, accuracy: 0.5)
        XCTAssertEqual(splits[1].seconds, expectedFull, accuracy: 0.5)
        XCTAssertFalse(splits[0].isPartial)
        XCTAssertTrue(splits[2].isPartial)
        XCTAssertEqual(splits[2].distanceMeters, total - 2000, accuracy: 0.5)
        XCTAssertEqual(splits.map(\.seconds).reduce(0, +), 24 * 30, accuracy: 0.5)
        XCTAssertEqual(splits[2].secondsPerKm, expectedFull, accuracy: 0.5)
    }

    func testShortRestIsDropped() {
        // 10 steps ≈ 1105.7 m: the 105 m rest is kept; 9 steps + a few metres is not.
        XCTAssertEqual(ActivityAnalysis.splits(line(11)).count, 2)
        var points = line(10)
        points.append(AnalysisPoint(timestamp: start.addingTimeInterval(300), latitude: 0.00905,
                                    longitude: 0, altitudeMeters: nil))
        XCTAssertEqual(ActivityAnalysis.splits(points).count, 1)
    }

    func testOneLongStepCrossesSeveralKilometres() {
        let points = [
            AnalysisPoint(timestamp: start, latitude: 0, longitude: 0, altitudeMeters: nil),
            AnalysisPoint(timestamp: start.addingTimeInterval(600), latitude: 0.0271, longitude: 0, altitudeMeters: nil),
        ]
        let splits = ActivityAnalysis.splits(points)
        XCTAssertEqual(splits.filter { !$0.isPartial }.count, 2)
        XCTAssertEqual(splits[0].seconds, splits[1].seconds, accuracy: 0.01)
    }

    func testUnorderedPointsAreSortedByTime() {
        XCTAssertEqual(ActivityAnalysis.splits(line(25).reversed()), ActivityAnalysis.splits(line(25)))
    }

    func testFastestIgnoresPartialAndNeedsTwoFull() {
        let splits = [
            ActivitySplit(index: 1, distanceMeters: 1000, seconds: 320),
            ActivitySplit(index: 2, distanceMeters: 1000, seconds: 298),
            ActivitySplit(index: 3, distanceMeters: 300, seconds: 60),
        ]
        XCTAssertEqual(ActivityAnalysis.fastestSplitIndex(splits), 2)
        XCTAssertNil(ActivityAnalysis.fastestSplitIndex([splits[0], splits[2]]))
    }

    func testElevationNeedsTwoAltitudes() {
        XCTAssertTrue(ActivityAnalysis.elevationProfile(line(10)).isEmpty)
        XCTAssertTrue(ActivityAnalysis.elevationProfile(line(10) { $0 == 3 ? 40 : nil }).isEmpty)
    }

    func testElevationFollowsDistance() {
        let profile = ActivityAnalysis.elevationProfile(line(5) { Double($0) * 2 })
        XCTAssertEqual(profile.count, 5)
        XCTAssertEqual(profile.map(\.altitudeMeters), [0, 2, 4, 6, 8])
        XCTAssertEqual(profile.last!.distanceMeters, stepMeters * 4, accuracy: 0.01)
    }

    func testElevationDownsamplesKeepingEnds() {
        let profile = ActivityAnalysis.elevationProfile(line(500) { Double($0) }, maxSamples: 50)
        XCTAssertEqual(profile.count, 50)
        XCTAssertEqual(profile.first?.altitudeMeters, 0)
        XCTAssertEqual(profile.last?.altitudeMeters, 499)
        XCTAssertEqual(profile.map(\.distanceMeters), profile.map(\.distanceMeters).sorted())
    }
}
