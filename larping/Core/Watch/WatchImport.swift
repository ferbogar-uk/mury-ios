import Foundation

/// Turns a recording made on the watch into the values `ActivitiesStore.create` takes,
/// and recognises one that was already imported. Foundation only, tested on Linux.
enum WatchImport {
    /// The `source` the imported activity is stored with.
    static let source = "watch"

    struct Values: Equatable {
        var sportType: SportType
        var startedAt: Date
        var endedAt: Date
        var durationSeconds: Int?
        var distanceMeters: Int
        var elevationGainMeters: Int?
        var averageSpeedMps: Double?
        var maxSpeedMps: Double?
        var trackPoints: [TrackPointPayload]

        static func == (lhs: Values, rhs: Values) -> Bool {
            lhs.sportType == rhs.sportType && lhs.startedAt == rhs.startedAt
                && lhs.endedAt == rhs.endedAt && lhs.durationSeconds == rhs.durationSeconds
                && lhs.distanceMeters == rhs.distanceMeters
                && lhs.elevationGainMeters == rhs.elevationGainMeters
                && lhs.averageSpeedMps == rhs.averageSpeedMps && lhs.maxSpeedMps == rhs.maxSpeedMps
                && lhs.trackPoints.count == rhs.trackPoints.count
        }
    }

    /// Nil when the sport is not one the iPhone knows (a file from a newer watch app).
    static func values(from record: WatchActivityRecord) -> Values? {
        guard let sport = SportType(rawValue: record.sport.rawValue) else { return nil }
        let formatter = ISO8601DateFormatter()
        let duration = record.durationSeconds > 0 ? record.durationSeconds : nil
        return Values(
            sportType: sport,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            durationSeconds: duration,
            distanceMeters: Int(record.distanceMeters),
            elevationGainMeters: record.elevationGainMeters > 0 ? Int(record.elevationGainMeters) : nil,
            averageSpeedMps: duration.map { record.distanceMeters / Double($0) },
            maxSpeedMps: record.maxSpeedMps > 0 ? record.maxSpeedMps : nil,
            trackPoints: record.points.map {
                TrackPointPayload(
                    timestamp: formatter.string(from: $0.timestamp),
                    latitude: $0.latitude, longitude: $0.longitude,
                    altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps,
                    heartRateBpm: $0.heartRateBpm, cadenceRpm: nil
                )
            }
        )
    }

    /// The iPhone keeps no id of the watch recording, so a repeat is recognised by being from
    /// the watch and starting at the same second. That is enough: two real recordings cannot
    /// start in the same second.
    static func isDuplicate(
        _ record: WatchActivityRecord, existing: [(source: String?, startedAt: Date)]
    ) -> Bool {
        existing.contains {
            $0.source == source && abs($0.startedAt.timeIntervalSince(record.startedAt)) < 1
        }
    }
}
