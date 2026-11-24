import XCTest
@testable import larping

final class MapboxCameraMathTests: XCTestCase {
    func testKnownDistanceAtTheEquator() {
        // 1000 m away, 800 pt tall view: 666.7 m visible -> 0.833 m/pt -> zoom log2(78271.5 / 0.833) = 16.52
        let zoom = MapboxCameraMath.zoom(forDistanceMeters: 1000, latitude: 0, viewHeightPoints: 800)
        XCTAssertEqual(zoom, 16.52, accuracy: 0.02)
    }

    func testCloserMeansMoreZoom() {
        let near = MapboxCameraMath.zoom(forDistanceMeters: 450, latitude: 51.5, viewHeightPoints: 800)
        let far = MapboxCameraMath.zoom(forDistanceMeters: 4500, latitude: 51.5, viewHeightPoints: 800)
        XCTAssertEqual(near - far, log2(10), accuracy: 0.001)
    }

    func testHigherLatitudeNeedsLessZoomForTheSameView() {
        let equator = MapboxCameraMath.zoom(forDistanceMeters: 1000, latitude: 0, viewHeightPoints: 800)
        let london = MapboxCameraMath.zoom(forDistanceMeters: 1000, latitude: 51.5, viewHeightPoints: 800)
        XCTAssertLessThan(london, equator)
    }

    func testBadInputStaysInsideTheZoomRange() {
        XCTAssertEqual(MapboxCameraMath.zoom(forDistanceMeters: 0, latitude: 0, viewHeightPoints: 800), 0)
        XCTAssertEqual(MapboxCameraMath.zoom(forDistanceMeters: 1, latitude: 0, viewHeightPoints: 800), 22)
        XCTAssertEqual(MapboxCameraMath.zoom(forDistanceMeters: 1000, latitude: 90, viewHeightPoints: 0), 0)
    }
}
