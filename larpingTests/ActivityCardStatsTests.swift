import XCTest
@testable import larping

final class ActivityCardStatsTests: XCTestCase {
    private func items(distance: String? = nil, pace: String? = nil, avg: Int? = nil, max: Int? = nil, kcal: Int? = nil) -> [ActivityCardStats.Item] {
        ActivityCardStats.items(distanceText: distance, durationText: "1:03:30", paceLabel: "Pace", paceText: pace,
                                averageHeartRate: avg, maxHeartRate: max, calories: kcal)
    }

    func testWalkKeepsDistanceTimeAndAverageHeartRate() {
        XCTAssertEqual(items(distance: "2.56 km", pace: "31:36", avg: 105).map(\.label), ["Distance", "Time", "Avg HR"])
    }

    func testRunWithoutHeartRateShowsPace() {
        XCTAssertEqual(items(distance: "5 km", pace: "5:30").map(\.label), ["Distance", "Time", "Pace"])
    }

    func testStrengthShowsTimeHeartRateAndCalories() {
        let result = items(avg: 67, max: 88, kcal: 312)
        XCTAssertEqual(result.map(\.label), ["Time", "Avg HR", "Calories"])
        XCTAssertEqual(result[2].value, "312 kcal")
    }

    func testStrengthWithoutCaloriesFallsBackToMaxHeartRate() {
        XCTAssertEqual(items(avg: 67, max: 88).map(\.label), ["Time", "Avg HR", "Max HR"])
    }

    func testOnlyTimeStillShowsOneNumber() {
        XCTAssertEqual(items(), [.init(label: "Time", value: "1:03:30")])
    }

    func testZeroValuesAreIgnored() {
        XCTAssertEqual(items(avg: 0, max: 0, kcal: 0).map(\.label), ["Time"])
    }
}
