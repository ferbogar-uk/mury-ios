import Foundation

/// Geodesic distance between two coordinates, in metres, on the WGS84 ellipsoid.
///
/// Foundation only, so it runs on Linux. It replaces `CLLocation.distance(from:)`
/// in the GPX importer and the recorder. Vincenty's inverse formula is used
/// because a spherical (haversine) estimate drifted up to 0.56% from CoreLocation
/// near the equator; GeoDistanceTests compares it with CoreLocation on macOS.
enum GeoDistance {
    private static let a = 6_378_137.0                 // WGS84 semi-major axis, metres
    private static let f = 1 / 298.257223563           // WGS84 flattening
    private static let b = (1 - f) * a                 // semi-minor axis

    static func meters(
        fromLatitude lat1: Double, longitude lon1: Double,
        toLatitude lat2: Double, longitude lon2: Double
    ) -> Double {
        if lat1 == lat2 && lon1 == lon2 { return 0 }
        let toRad = Double.pi / 180
        let L = (lon2 - lon1) * toRad
        let u1 = atan((1 - f) * tan(lat1 * toRad))
        let u2 = atan((1 - f) * tan(lat2 * toRad))
        let sinU1 = sin(u1), cosU1 = cos(u1)
        let sinU2 = sin(u2), cosU2 = cos(u2)

        var lambda = L
        var sinSigma = 0.0, cosSigma = 0.0, sigma = 0.0
        var cosSqAlpha = 0.0, cos2SigmaM = 0.0
        var converged = false
        for _ in 0..<200 {
            let sinLambda = sin(lambda), cosLambda = cos(lambda)
            let x = cosU2 * sinLambda
            let y = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda
            sinSigma = (x * x + y * y).squareRoot()
            if sinSigma == 0 { return 0 }
            cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
            sigma = atan2(sinSigma, cosSigma)
            let sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
            cosSqAlpha = 1 - sinAlpha * sinAlpha
            cos2SigmaM = cosSqAlpha != 0 ? cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha : 0
            let c = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
            let previous = lambda
            lambda = L + (1 - c) * f * sinAlpha
                * (sigma + c * sinSigma * (cos2SigmaM + c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
            if abs(lambda - previous) < 1e-12 { converged = true; break }
        }
        // Nearly antipodal points may not converge; fall back to the sphere.
        if !converged { return haversine(lat1, lon1, lat2, lon2) }

        let uSq = cosSqAlpha * (a * a - b * b) / (b * b)
        let bigA = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let bigB = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
        let deltaSigma = bigB * sinSigma * (cos2SigmaM + bigB / 4
            * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
               - bigB / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
        return b * bigA * (sigma - deltaSigma)
    }

    private static func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let toRad = Double.pi / 180
        let dLat = (lat2 - lat1) * toRad, dLon = (lon2 - lon1) * toRad
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * 6_371_008.8 * atan2(h.squareRoot(), (1 - h).squareRoot())
    }
}
