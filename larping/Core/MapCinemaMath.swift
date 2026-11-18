import Foundation

/// Foundation-only helpers for the MapTiler "Map cinema" test screen.
nonisolated enum MapCinemaMath {
    /// Web-map zoom for a camera `distance` metres from the centre on a portrait phone (about 844 points tall,
    /// camera distance about 1.5 screen heights of ground). An approximation: it keeps the framing close to the
    /// Apple Maps flyover, not identical.
    static func zoom(forDistance distance: Double, latitude: Double) -> Double {
        let metersPerPoint = max(0.05, distance) / (1.5 * 844)
        let cosine = max(0.1, cos(latitude * Double.pi / 180))
        return min(22, max(1, log2(78_271.5 * cosine / metersPerPoint)))
    }

    /// GeoJSON feature collection with one LineString per segment of two or more points. Coordinates are
    /// longitude, latitude, in that order.
    static func geoJSON(segments: [[ReplayCoordinate]]) -> String {
        let lines = segments.filter { $0.count > 1 }.map { segment -> String in
            let coordinates = segment.map { String(format: "[%.6f,%.6f]", $0.longitude, $0.latitude) }.joined(separator: ",")
            return "{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[\(coordinates)]}}"
        }
        return "{\"type\":\"FeatureCollection\",\"features\":[\(lines.joined(separator: ","))]}"
    }
}
