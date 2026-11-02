import CoreLocation
import XCTest
@testable import larping

@MainActor
final class ShareRouteTests: XCTestCase {
    private func point(_ x: Double) -> CLLocationCoordinate2D { .init(latitude: 0, longitude: x) }

    func testDistanceRevealInterpolatesUnevenSamples() {
        let route = ShareRoute(segments: [[point(0), point(0.001), point(0.01)]])
        XCTAssertEqual(route.revealedSegments(at: 0).first?.count, 1)
        XCTAssertEqual(route.revealedSegments(at: 0.5).last?.last?.longitude ?? -1, 0.005, accuracy: 0.000001)
        XCTAssertEqual(route.revealedSegments(at: 1).last?.last?.longitude, 0.01)
    }

    func testGapsAndInvalidCoordinatesNeverBecomeEdges() {
        let route = ShareRoute(segments: [[point(0), point(0.001)], [point(10), point(.nan), point(20), point(20.001)]])
        XCTAssertEqual(route.segments.count, 3)
        let expected = CLLocation(latitude: 0, longitude: 0).distance(from: CLLocation(latitude: 0, longitude: 0.001)) * 2
        XCTAssertEqual(route.totalDistance, expected, accuracy: 0.01)
        XCTAssertEqual(route.revealedSegments(at: 0.75).last?.last?.longitude ?? -1, 20.0005, accuracy: 0.000001)
    }

    func testDateLineInterpolationUsesShortLongitudeArc() {
        let route = ShareRoute(segments: [[point(179), point(-179)]])
        XCTAssertEqual(abs(route.revealedSegments(at: 0.5).last?.last?.longitude ?? 0), 180, accuracy: 0.000001)
        XCTAssertEqual(route.revealedSegments(at: 1).last?.last?.longitude, -179)
    }

    func testDuplicatesStationaryAndNonfiniteProgressAreDeterministic() {
        let route = ShareRoute(segments: [[point(1), point(1)], [], [.init(latitude: 91, longitude: 0)]])
        XCTAssertEqual(route.totalDistance, 0)
        XCTAssertEqual(route.segments.count, 1)
        for progress in [0, 0.5, 1, -.infinity, .infinity, .nan] {
            XCTAssertEqual(route.revealedSegments(at: progress).first?.first?.longitude, 1)
        }
        XCTAssertTrue(ShareRoute(segments: []).revealedSegments(at: 1).isEmpty)
        let moving = ShareRoute(segments: [[point(0), point(1)]])
        XCTAssertEqual(moving.revealedSegments(at: .nan).first?.last?.longitude, 0)
        XCTAssertEqual(moving.revealedSegments(at: .infinity).first?.last?.longitude, 1)
        XCTAssertEqual(moving.revealedSegments(at: -1).first?.last?.longitude, 0)
    }
}
