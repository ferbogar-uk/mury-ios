import XCTest
@testable import larping

final class RouteSmoothingTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1000)

    private func point(_ second: Double, _ lat: Double, _ lon: Double) -> ReplayPoint {
        ReplayPoint(timestamp: origin.addingTimeInterval(second), latitude: lat, longitude: lon)
    }

    func testStraightLineStaysStraight() {
        let points = (0..<30).map { point(Double($0), 0, Double($0) * 0.0001) }
        let out = RouteSmoothing.smoothed(points, halfWindowSeconds: 5)
        XCTAssertEqual(out.count, points.count)
        for (a, b) in zip(points, out).dropFirst(6).dropLast(6) {
            XCTAssertEqual(a.latitude, b.latitude, accuracy: 1e-9)
            XCTAssertEqual(a.longitude, b.longitude, accuracy: 1e-9)
        }
    }

    func testZigzagWobbleShrinks() {
        let points = (0..<40).map { point(Double($0), $0 % 2 == 0 ? 0.0001 : -0.0001, Double($0) * 0.0001) }
        let out = RouteSmoothing.smoothed(points, halfWindowSeconds: 6)
        let before = points.dropFirst(8).dropLast(8).map { abs($0.latitude) }.max() ?? 0
        let after = zip(points, out).enumerated().filter { $0.offset >= 8 && $0.offset < 32 }.map { abs($0.element.1.latitude) }.max() ?? 1
        XCTAssertLessThan(after, before / 3)
    }

    func testEndpointsStayExactAndCountIsKept() {
        let points = (0..<20).map { point(Double($0), Double($0 % 3) * 0.0001, Double($0) * 0.0001) }
        let out = RouteSmoothing.smoothed(points, halfWindowSeconds: 4)
        XCTAssertEqual(out.count, 20)
        XCTAssertEqual(out.first?.latitude, points.first?.latitude)
        XCTAssertEqual(out.first?.longitude, points.first?.longitude)
        XCTAssertEqual(out.last?.latitude, points.last?.latitude)
        XCTAssertEqual(out.last?.longitude, points.last?.longitude)
    }

    func testUnsortedInputComesBackSorted() {
        let points = [point(5, 0, 0.5), point(1, 0, 0.1), point(3, 0, 0.3), point(2, 0, 0.2), point(4, 0, 0.4)]
        let out = RouteSmoothing.smoothed(points, halfWindowSeconds: 2)
        XCTAssertEqual(out.map { $0.timestamp }, out.map { $0.timestamp }.sorted())
    }

    func testTinyAndInvalidInputAreReturnedUnchanged() {
        XCTAssertTrue(RouteSmoothing.smoothed([], halfWindowSeconds: 5).isEmpty)
        let one = [point(0, 1, 1)]
        XCTAssertEqual(RouteSmoothing.smoothed(one, halfWindowSeconds: 5).count, 1)
        let three = [point(0, 0, 0), point(1, 1, 1), point(2, 0, 0)]
        XCTAssertEqual(RouteSmoothing.smoothed(three, halfWindowSeconds: 0)[1].latitude, 1)
    }

    func testFarGapIsNotBlended() {
        let points = [point(0, 0, 0), point(1, 0, 0.0001), point(2, 0, 0.0002), point(600, 1, 1), point(601, 1, 1.0001), point(602, 1, 1.0002)]
        let out = RouteSmoothing.smoothed(points, halfWindowSeconds: 10)
        XCTAssertEqual(out[2].latitude, 0, accuracy: 1e-9)
        XCTAssertEqual(out[3].latitude, 1, accuracy: 1e-9)
    }
}
