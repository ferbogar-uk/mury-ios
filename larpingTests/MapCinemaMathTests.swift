import XCTest
@testable import larping

final class MapCinemaMathTests: XCTestCase {
    func testZoomGrowsAsTheCameraComesCloser() {
        let far = MapCinemaMath.zoom(forDistance: 5_000, latitude: 51.5)
        let near = MapCinemaMath.zoom(forDistance: 450, latitude: 51.5)
        XCTAssertGreaterThan(near, far)
        XCTAssertEqual(near, 17.0, accuracy: 0.6)
    }

    func testZoomIsClampedForOddInput() {
        XCTAssertLessThanOrEqual(MapCinemaMath.zoom(forDistance: 0, latitude: 90), 22)
        XCTAssertGreaterThanOrEqual(MapCinemaMath.zoom(forDistance: 1e12, latitude: 0), 1)
    }

    func testGeoJSONUsesLongitudeFirstAndSkipsSinglePoints() throws {
        let line = [ReplayCoordinate(latitude: 51.5, longitude: -0.12), ReplayCoordinate(latitude: 51.6, longitude: -0.13)]
        let single = [ReplayCoordinate(latitude: 1, longitude: 2)]
        let text = MapCinemaMath.geoJSON(segments: [line, single])
        XCTAssertTrue(text.contains("[-0.120000,51.500000]"))
        XCTAssertFalse(text.contains("[2.000000,1.000000]"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual((object["features"] as? [Any])?.count, 1)
    }

    func testEmptyRouteIsValidGeoJSON() throws {
        let text = MapCinemaMath.geoJSON(segments: [])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "FeatureCollection")
    }

    func testKeyTextIsTrimmedAndEmptyIsRejected() {
        XCTAssertEqual(MapTilerConfig.clean("  abc123\n"), "abc123")
        XCTAssertNil(MapTilerConfig.clean(" \n "))
    }

    func testTrailFeaturesCarryRunningIndexAcrossSegments() throws {
        let a = [ReplayCoordinate(latitude: 1, longitude: 2), ReplayCoordinate(latitude: 1, longitude: 3), ReplayCoordinate(latitude: 1, longitude: 4)]
        let b = [ReplayCoordinate(latitude: 5, longitude: 6), ReplayCoordinate(latitude: 5, longitude: 7)]
        let text = MapCinemaMath.trailGeoJSON(segments: [a, b])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let features = try XCTUnwrap(object["features"] as? [[String: Any]])
        let indexes = features.compactMap { ($0["properties"] as? [String: Int])?["i"] }
        XCTAssertEqual(indexes, [1, 2, 4])
    }
}
