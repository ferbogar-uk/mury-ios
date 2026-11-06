import Foundation

// Heart-rate zones and the graph series for the activity detail. Foundation
// only, so the arithmetic runs on Linux and is tested with fixed numbers.

/// One heart-rate reading saved with an activity.
nonisolated struct HeartRateSample: Equatable {
    var timestamp: Date
    var bpm: Int
}

/// The five zones, as shares of the maximum heart rate.
nonisolated enum HeartRateZone: Int, CaseIterable, Identifiable, Equatable {
    case z1 = 1, z2, z3, z4, z5

    var id: Int { rawValue }

    var shortName: String { "Z\(rawValue)" }

    var name: String {
        switch self {
        case .z1: return "Very easy"
        case .z2: return "Easy"
        case .z3: return "Moderate"
        case .z4: return "Hard"
        case .z5: return "Maximum"
        }
    }

    /// Where the zone starts, as a share of the maximum. Everything below 60%
    /// counts as zone 1, so no reading falls outside the five zones.
    var lowerFraction: Double {
        switch self {
        case .z1: return 0
        case .z2: return 0.6
        case .z3: return 0.7
        case .z4: return 0.8
        case .z5: return 0.9
        }
    }
}

/// Time spent in one zone.
nonisolated struct ZoneDuration: Equatable, Identifiable {
    let zone: HeartRateZone
    let seconds: Int
    /// Share of the counted time, 0...1.
    let fraction: Double
    var id: Int { zone.id }
}

/// The zone edges for one maximum heart rate.
nonisolated struct HeartRateZones: Equatable {
    let maxBpm: Int

    /// Nil when there is no usable maximum.
    init?(maxBpm: Int?) {
        guard let maxBpm, maxBpm > 0 else { return nil }
        self.maxBpm = maxBpm
    }

    /// The lowest bpm that belongs to the zone. Edges are rounded to the nearest
    /// whole bpm, halves up, so 185 gives 111, 130, 148 and 167.
    func lowerEdge(of zone: HeartRateZone) -> Int {
        Int((Double(maxBpm) * zone.lowerFraction).rounded(.toNearestOrAwayFromZero))
    }

    func zone(for bpm: Int) -> HeartRateZone {
        for zone in HeartRateZone.allCases.reversed() where bpm >= lowerEdge(of: zone) {
            return zone
        }
        return .z1
    }

    /// "under 111 bpm", "111–130 bpm", "167+ bpm".
    func rangeText(of zone: HeartRateZone) -> String {
        switch zone {
        case .z1: return "under \(lowerEdge(of: .z2)) bpm"
        case .z5: return "\(lowerEdge(of: .z5))+ bpm"
        default:
            let next = HeartRateZone(rawValue: zone.rawValue + 1)!
            return "\(lowerEdge(of: zone))–\(lowerEdge(of: next)) bpm"
        }
    }

    /// Seconds in each zone, always five entries from Z1 to Z5. A reading counts
    /// until the next one. When two readings are further apart than
    /// `maxGapSeconds` (watch off, recording paused) the gap counts for nothing,
    /// so a pause never inflates a zone.
    func timeInZones(_ samples: [HeartRateSample], maxGapSeconds: TimeInterval = 30) -> [ZoneDuration] {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        var seconds = [HeartRateZone: Double]()
        for (current, next) in zip(sorted, sorted.dropFirst()) {
            let gap = next.timestamp.timeIntervalSince(current.timestamp)
            guard gap > 0, gap <= maxGapSeconds else { continue }
            seconds[zone(for: current.bpm), default: 0] += gap
        }
        let total = seconds.values.reduce(0, +)
        return HeartRateZone.allCases.map { zone in
            let value = seconds[zone] ?? 0
            return ZoneDuration(
                zone: zone,
                seconds: Int(value.rounded()),
                fraction: total > 0 ? value / total : 0
            )
        }
    }

    /// The highest heart rate recorded in any real activity. Sample activities
    /// are demo data and never count, like in the statistics.
    static func measuredMaxBpm(in entries: [StatsEntry]) -> Int? {
        entries
            .filter { $0.source != StatsEntry.sampleSource }
            .compactMap(\.maxHeartRateBpm)
            .filter { $0 > 0 }
            .max()
    }
}

/// One point on the heart-rate graph.
nonisolated struct HeartRatePoint: Equatable, Identifiable {
    /// Seconds since the start of the activity.
    let seconds: Double
    let bpm: Double
    var id: Double { seconds }
}

nonisolated enum HeartRateSeries {
    /// The graph series, oldest first. Long recordings are averaged in equal
    /// buckets down to at most `maxPoints`, so the chart stays light.
    static func points(from samples: [HeartRateSample], origin: Date, maxPoints: Int = 200) -> [HeartRatePoint] {
        let sorted = samples.filter { $0.bpm > 0 }.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty, maxPoints > 0 else { return [] }
        let bucketSize = max(1, Int((Double(sorted.count) / Double(maxPoints)).rounded(.up)))
        return stride(from: 0, to: sorted.count, by: bucketSize).map { start in
            let bucket = sorted[start..<min(start + bucketSize, sorted.count)]
            let count = Double(bucket.count)
            let seconds = bucket.reduce(0.0) { $0 + $1.timestamp.timeIntervalSince(origin) } / count
            let bpm = bucket.reduce(0.0) { $0 + Double($1.bpm) } / count
            return HeartRatePoint(seconds: max(0, seconds), bpm: bpm)
        }
    }

    /// The point closest in time to `seconds`, for reading the graph by touch.
    static func nearest(to seconds: Double, in points: [HeartRatePoint]) -> HeartRatePoint? {
        points.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) }
    }
}
