import Foundation

/// Great-circle distance between two coordinates, in metres.
///
/// Foundation only, so it runs on Linux. It replaces `CLLocation.distance(from:)`
/// in the GPX importer. GeoDistanceTests compares it with CoreLocation on macOS
/// over real-world routes, so a drift from the iPhone's own numbers is caught.
enum GeoDistance {
    /// Mean Earth radius (IUGG), metres.
    private static let earthRadius = 6_371_008.8

    static func meters(
        fromLatitude lat1: Double, longitude lon1: Double,
        toLatitude lat2: Double, longitude lon2: Double
    ) -> Double {
        let toRad = Double.pi / 180
        let dLat = (lat2 - lat1) * toRad
        let dLon = (lon2 - lon1) * toRad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}
