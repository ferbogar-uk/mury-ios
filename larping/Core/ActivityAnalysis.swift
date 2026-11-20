import Foundation

/// One GPS reading, reduced to what splits and the elevation profile need.
struct AnalysisPoint: Equatable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
}

/// Time for one kilometre (or the shorter last stretch).
struct ActivitySplit: Equatable, Identifiable {
    /// 1-based, as shown on screen.
    let index: Int
    let distanceMeters: Double
    let seconds: Double
    var id: Int { index }
    /// True for the last stretch when it is shorter than a full kilometre.
    var isPartial: Bool { distanceMeters < ActivityAnalysis.splitMeters - 0.5 }
    /// Pace scaled to a full kilometre, so a partial split compares fairly.
    var secondsPerKm: Double { distanceMeters > 0 ? seconds / distanceMeters * 1000 : 0 }
}

struct ElevationSample: Equatable {
    let distanceMeters: Double
    let altitudeMeters: Double
}

/// Splits and elevation profile for the activity detail, worked out from the
/// stored track points. Foundation only, so it is tested on Linux.
enum ActivityAnalysis {
    static let splitMeters = 1000.0
    /// A last stretch shorter than this is not shown as its own split.
    static let minimumPartialMeters = 100.0

    static func splits(_ points: [AnalysisPoint]) -> [ActivitySplit] {
        let ordered = points.sorted { $0.timestamp < $1.timestamp }
        guard ordered.count > 1 else { return [] }
        var result: [ActivitySplit] = []
        var covered = 0.0          // distance from the start to the current point
        var splitStartTime = ordered[0].timestamp
        var nextBoundary = splitMeters
        for (previous, point) in zip(ordered, ordered.dropFirst()) {
            let step = GeoDistance.meters(
                fromLatitude: previous.latitude, longitude: previous.longitude,
                toLatitude: point.latitude, longitude: point.longitude)
            guard step > 0 else { continue }
            let stepSeconds = point.timestamp.timeIntervalSince(previous.timestamp)
            // A long step can cross more than one kilometre mark.
            while covered + step >= nextBoundary {
                let fraction = (nextBoundary - covered) / step
                let crossing = previous.timestamp.addingTimeInterval(stepSeconds * fraction)
                result.append(ActivitySplit(index: result.count + 1, distanceMeters: splitMeters,
                                            seconds: crossing.timeIntervalSince(splitStartTime)))
                splitStartTime = crossing
                nextBoundary += splitMeters
            }
            covered += step
        }
        let rest = covered - (nextBoundary - splitMeters)
        if rest >= minimumPartialMeters, let last = ordered.last {
            result.append(ActivitySplit(index: result.count + 1, distanceMeters: rest,
                                        seconds: last.timestamp.timeIntervalSince(splitStartTime)))
        }
        return result
    }

    /// Index (1-based) of the quickest full kilometre; nil with fewer than two full ones.
    static func fastestSplitIndex(_ splits: [ActivitySplit]) -> Int? {
        let full = splits.filter { !$0.isPartial && $0.seconds > 0 }
        guard full.count > 1 else { return nil }
        return full.min { $0.seconds < $1.seconds }?.index
    }

    /// Altitude against distance, at most `maxSamples` points (first and last kept).
    /// Empty when fewer than two readings carry an altitude.
    static func elevationProfile(_ points: [AnalysisPoint], maxSamples: Int = 120) -> [ElevationSample] {
        let ordered = points.sorted { $0.timestamp < $1.timestamp }
        var samples: [ElevationSample] = []
        var covered = 0.0
        for (offset, point) in ordered.enumerated() {
            if offset > 0 {
                let previous = ordered[offset - 1]
                covered += GeoDistance.meters(
                    fromLatitude: previous.latitude, longitude: previous.longitude,
                    toLatitude: point.latitude, longitude: point.longitude)
            }
            if let altitude = point.altitudeMeters {
                samples.append(ElevationSample(distanceMeters: covered, altitudeMeters: altitude))
            }
        }
        guard samples.count > 1 else { return [] }
        guard samples.count > maxSamples, maxSamples > 1 else { return samples }
        let stride = Double(samples.count - 1) / Double(maxSamples - 1)
        return (0..<maxSamples).map { samples[Int((Double($0) * stride).rounded())] }
    }
}
