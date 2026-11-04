import XCTest
@testable import larping
#if canImport(CoreLocation)
import CoreLocation
#endif

final class GeoDistanceTests: XCTestCase {
    func testKnownDistances() {
        // One degree of latitude at the equator is about 110.57 km on the WGS84 ellipsoid.
        XCTAssertEqual(
            GeoDistance.meters(fromLatitude: 0, longitude: 0, toLatitude: 1, longitude: 0),
            110_574, accuracy: 5
        )
        // London to Paris is about 343.9 km.
        XCTAssertEqual(
            GeoDistance.meters(fromLatitude: 51.5074, longitude: -0.1278, toLatitude: 48.8566, longitude: 2.3522),
            343_923, accuracy: 20
        )
    }

    func testSamePointIsZero() {
        XCTAssertEqual(
            GeoDistance.meters(fromLatitude: 51.5, longitude: -0.1, toLatitude: 51.5, longitude: -0.1), 0
        )
    }

    func testIsSymmetric() {
        let a = GeoDistance.meters(fromLatitude: 10, longitude: 20, toLatitude: 11, longitude: 22)
        let b = GeoDistance.meters(fromLatitude: 11, longitude: 22, toLatitude: 10, longitude: 20)
        XCTAssertEqual(a, b, accuracy: 0.001)
    }

    #if canImport(CoreLocation)
    /// The importer used CLLocation before. Over short GPS steps and over long
    /// legs, the replacement must stay within 0.05% of what the iPhone computed.
    func testMatchesCoreLocationWithinOneTwentiethOfAPercent() {
        let steps: [(Double, Double, Double, Double)] = [
            (51.5074, -0.1278, 51.5075, -0.1279),   // ~13 m, London
            (51.5074, -0.1278, 51.5174, -0.1178),   // ~1.3 km
            (51.5074, -0.1278, 51.6074, 0.0722),    // ~16 km
            (51.5074, -0.1278, 48.8566, 2.3522),    // London - Paris
            (-23.5505, -46.6333, -22.9068, -43.1729), // Sao Paulo - Rio
            (64.1466, -21.9426, 64.1566, -21.9026), // Reykjavik, high latitude
            (0.0, 0.0, 0.001, 0.001),               // equator
            (1.0, 1.0, 1.001, 1.0),                 // the GPX test fixture
        ]
        for (lat1, lon1, lat2, lon2) in steps {
            let apple = CLLocation(latitude: lat2, longitude: lon2)
                .distance(from: CLLocation(latitude: lat1, longitude: lon1))
            let ours = GeoDistance.meters(fromLatitude: lat1, longitude: lon1, toLatitude: lat2, longitude: lon2)
            let relative = abs(ours - apple) / apple
            XCTAssertLessThan(relative, 0.0005, "(\(lat1),\(lon1))->(\(lat2),\(lon2)): apple=\(apple) ours=\(ours) diff=\(relative * 100)%")
        }
    }
    #endif
}
