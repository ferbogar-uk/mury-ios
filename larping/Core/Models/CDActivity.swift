import Foundation
import SwiftData

@Model
final class CDActivity {
    var id = UUID()
    var sportTypeRaw: String = SportType.run.rawValue
    var startedAt: Date = Date()
    var endedAt: Date?
    var durationSeconds: Int?
    var distanceMeters: Int?
    var elevationGainMeters: Int?
    var averageSpeedMps: Double?
    var maxSpeedMps: Double?
    var source: String = "mobile"
    var eventName: String?
    /// Id of the Health workout this activity was imported from (nil for MURY recordings).
    var externalID: String?
    /// Heart rate for activities with no route (see `HeartRateSeriesCodec`); nil otherwise.
    var heartRateSeriesData: Data?
    /// Active energy from Apple Health, in kcal (nil when Health had none).
    var energyKcal: Int?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CDTrackPoint.activity)
    var trackPoints: [CDTrackPoint] = []

    var sportType: SportType {
        get { SportType(rawValue: sportTypeRaw) ?? .run }
        set { sportTypeRaw = newValue.rawValue }
    }

    @Transient
    var averagePaceSecondsPerKm: Int? {
        guard sportType.usesPaceMetric,
              let averageSpeedMps, averageSpeedMps > 0.1 else { return nil }
        return Int(1000 / averageSpeedMps)
    }

    /// Calories: Health's measured active energy when there is one, otherwise a rough estimate.
    @Transient
    var calories: Int? {
        if let energyKcal, energyKcal > 0 { return energyKcal }
        guard let distanceMeters, let durationSeconds, durationSeconds > 0 else { return nil }
        let km = Double(distanceMeters) / 1000
        let hours = Double(durationSeconds) / 3600
        return Int(km * hours * 60)
    }

    /// True when `calories` is Health's measured figure, not the estimate.
    @Transient
    var caloriesMeasured: Bool { (energyKcal ?? 0) > 0 }

    /// Heart rate over the activity: from the GPS points when they carry it,
    /// otherwise from the stored series (activities without a route).
    @Transient
    var heartRateSamples: [HeartRateSample] {
        let fromPoints = trackPoints.compactMap { point -> HeartRateSample? in
            guard let bpm = point.heartRateBpm, bpm > 0 else { return nil }
            return HeartRateSample(timestamp: point.timestamp, bpm: bpm)
        }
        return fromPoints.isEmpty ? HeartRateSeriesCodec.decode(heartRateSeriesData) : fromPoints
    }

    /// Highest heart rate (nil when the activity has none — live iPhone
    /// recordings never populate HR; HealthKit-imported ones do).
    @Transient
    var maxHeartRateBpm: Int? {
        heartRateSamples.map(\.bpm).max()
    }

    @Transient
    var averageHeartRateBpm: Int? {
        let rates = heartRateSamples.map(\.bpm)
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / rates.count
    }

    /// The one shape every screen hands to StatsSummary, so Home, the activity
    /// list and Stats all count a week the same way.
    @Transient
    var statsEntry: StatsEntry {
        StatsEntry(
            startedAt: startedAt, sport: sportType,
            distanceMeters: distanceMeters, durationSeconds: durationSeconds,
            maxHeartRateBpm: maxHeartRateBpm, source: source
        )
    }

    init() {}
}