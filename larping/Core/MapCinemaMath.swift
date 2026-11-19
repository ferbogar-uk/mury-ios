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

    /// Bounding box of all points, or nil when there are none.
    static func bounds(of segments: [[ReplayCoordinate]]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let points = segments.flatMap { $0 }
        guard let first = points.first else { return nil }
        var box = (minLat: first.latitude, maxLat: first.latitude, minLon: first.longitude, maxLon: first.longitude)
        for point in points {
            box.minLat = min(box.minLat, point.latitude)
            box.maxLat = max(box.maxLat, point.latitude)
            box.minLon = min(box.minLon, point.longitude)
            box.maxLon = max(box.maxLon, point.longitude)
        }
        return box
    }

    /// Zoom that frames a bounding box plus `marginMeters` on every side on a portrait phone (about 390 by 844
    /// points), looking straight down. Clamped to 10...18.
    static func overviewZoom(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, marginMeters: Double) -> Double {
        let midLat = (minLat + maxLat) / 2
        let height = (maxLat - minLat) * 111_320 + 2 * marginMeters
        let width = (maxLon - minLon) * 111_320 * max(0.1, cos(midLat * Double.pi / 180)) + 2 * marginMeters
        let metersPerPoint = max(height / 844, width / 390)
        let cosine = max(0.1, cos(midLat * Double.pi / 180))
        return min(18, max(10, log2(78_271.5 * cosine / metersPerPoint)))
    }
}
