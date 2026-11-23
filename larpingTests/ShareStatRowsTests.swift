import XCTest
@testable import larping

final class ShareStatRowsTests: XCTestCase {
    func testRunKeepsDistanceDurationAndPace() {
        let rows = ShareStatRows.rows(distance: "5.25 km", duration: "0:30:00", metricLabel: "PACE", paceOrSpeed: "5:30",
                                      averageHeartRate: "150 bpm", maxHeartRate: "171 bpm")
        XCTAssertEqual(rows.map(\.label), ["DISTANCE", "DURATION", "PACE"])
    }

    func testStrengthDropsEmptyRowsAndShowsHeartRate() {
        let rows = ShareStatRows.rows(distance: "–", duration: "1:03:30", metricLabel: "SPEED", paceOrSpeed: "–",
                                      averageHeartRate: "67 bpm", maxHeartRate: "88 bpm")
        XCTAssertEqual(rows, [.init(label: "DURATION", value: "1:03:30"),
                              .init(label: "AVG HEART RATE", value: "67 bpm"),
                              .init(label: "MAX HEART RATE", value: "88 bpm")])
    }

    func testNoHeartRateAndNoDistanceStillShowsDuration() {
        let rows = ShareStatRows.rows(distance: "–", duration: "0:45:00", metricLabel: "SPEED", paceOrSpeed: "–",
                                      averageHeartRate: "–", maxHeartRate: "–")
        XCTAssertEqual(rows, [.init(label: "DURATION", value: "0:45:00")])
    }

    func testNothingAtAllStillReturnsDurationRow() {
        let rows = ShareStatRows.rows(distance: "–", duration: "–", metricLabel: "SPEED", paceOrSpeed: "–",
                                      averageHeartRate: "–", maxHeartRate: "–")
        XCTAssertEqual(rows.map(\.label), ["DURATION"])
    }

    func testHeartRateText() {
        XCTAssertEqual(ShareStatRows.heartRateText(67), "67 bpm")
        XCTAssertEqual(ShareStatRows.heartRateText(nil), "–")
        XCTAssertEqual(ShareStatRows.heartRateText(0), "–")
    }
}
