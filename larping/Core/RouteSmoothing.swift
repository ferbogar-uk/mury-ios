import Foundation

/// Foundation-only smoothing of a GPS track for display (flyover line and camera).
/// Averages each point with its neighbours within a time window, so the line follows the general
/// path instead of the GPS wobble. First and last points stay exact so start and end markers sit on the real spots.
enum RouteSmoothing {
    /// Triangular-weighted average of latitude and longitude over +-`halfWindowSeconds`.
    /// Timestamps and other fields are kept; points are returned sorted by time.
    static func smoothed(_ points: [ReplayPoint], halfWindowSeconds: TimeInterval) -> [ReplayPoint] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count > 2, halfWindowSeconds.isFinite, halfWindowSeconds > 0 else { return sorted }
        var result = sorted
        var lower = 0
        var upper = 0
        for index in 1..<(sorted.count - 1) {
            let time = sorted[index].timestamp
            while time.timeIntervalSince(sorted[lower].timestamp) > halfWindowSeconds { lower += 1 }
            if upper < index { upper = index }
            while upper + 1 < sorted.count, sorted[upper + 1].timestamp.timeIntervalSince(time) <= halfWindowSeconds { upper += 1 }
            var weightSum = 0.0
            var latitude = 0.0
            var longitude = 0.0
            for neighbour in lower...upper {
                let distance = abs(sorted[neighbour].timestamp.timeIntervalSince(time))
                let weight = 1 - distance / (halfWindowSeconds + 1)
                weightSum += weight
                latitude += sorted[neighbour].latitude * weight
                longitude += sorted[neighbour].longitude * weight
            }
            guard weightSum > 0 else { continue }
            let original = sorted[index]
            result[index] = ReplayPoint(timestamp: original.timestamp,
                                        latitude: latitude / weightSum,
                                        longitude: longitude / weightSum,
                                        altitudeMeters: original.altitudeMeters,
                                        speedMps: original.speedMps)
        }
        return result
    }
}
