import CoreLocation
import Foundation
import HealthKit

struct HealthSyncResult: Equatable {
    var imported = 0
    var skipped = 0
    var failed = 0
}

/// Brings Health workouts into MURY: the 90-day backfill, later top-ups, and the one-workout import the
/// picker uses. Which workouts to take is decided by `HealthImportRules`; this file only talks to HealthKit.
@MainActor
enum HealthSync {
    static let lastSyncKey = "lastHealthSync"
    private static var isRunning = false

    /// Imports every Health workout in the window that MURY does not already hold, oldest first, one at a time.
    static func run(store: ActivitiesStore, days: Int = HealthImportRules.backfillDays) async -> HealthSyncResult {
        guard HealthKitService.isAvailable, !isRunning else { return HealthSyncResult() }
        isRunning = true
        defer { isRunning = false }

        let now = Date()
        guard let workouts = try? await HealthKitService.fetchWorkouts(since: now.addingTimeInterval(-Double(days) * 86_400)) else {
            return HealthSyncResult()
        }
        let byID = Dictionary(workouts.map { ($0.uuid.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        let records = workouts.map(record(from:))
        let selected = HealthImportRules.select(records, existing: store.existingImports(), now: now, days: days)

        var result = HealthSyncResult(skipped: workouts.count - selected.count)
        for item in selected {
            guard let workout = byID[item.externalID] else { continue }
            do {
                try await importOne(workout, sport: SportType(workoutActivityType: workout.workoutActivityType), store: store)
                result.imported += 1
            } catch {
                result.failed += 1
            }
        }
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        return result
    }

    /// Runs a sync unless one ran in the last ten minutes.
    static func runIfDue(store: ActivitiesStore) async {
        let last = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        guard HealthImportRules.shouldSync(last: last, now: Date()) else { return }
        _ = await run(store: store)
    }

    static func record(from workout: HKWorkout) -> HealthWorkoutRecord {
        HealthWorkoutRecord(
            externalID: workout.uuid.uuidString,
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            durationSeconds: workout.duration > 0 ? Int(workout.duration) : Int(workout.endDate.timeIntervalSince(workout.startDate)),
            writtenByMury: workout.metadata?["larping.activityID"] != nil
        )
    }

    /// Saves one Health workout as an activity, with its route and heart rate when Health has them.
    static func importOne(_ workout: HKWorkout, sport: SportType, store: ActivitiesStore) async throws {
        let duration = workout.duration > 0 ? Int(workout.duration) : Int(workout.endDate.timeIntervalSince(workout.startDate))
        let route = await HealthKitService.fetchRoute(for: workout)
        let heartRate = await HealthKitService.heartRateSamples(for: workout)

        let distance: Double
        if let total = workout.totalDistance?.doubleValue(for: .meter()), total > 0 {
            distance = total
        } else {
            distance = routeDistance(route)
        }
        let gain = elevationGain(route)

        try store.create(
            sportType: sport,
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            durationSeconds: duration > 0 ? duration : nil,
            distanceMeters: distance > 0 ? Int(distance) : nil,
            elevationGainMeters: gain > 0 ? Int(gain) : nil,
            averageSpeedMps: duration > 0 && distance > 0 ? distance / Double(duration) : nil,
            maxSpeedMps: maxSpeed(route),
            source: "healthkit_import",
            externalID: workout.uuid.uuidString,
            trackPointsPayloads: trackPoints(route: route, heartRate: heartRate)
        )
    }

    private static func routeDistance(_ route: [CLLocation]) -> Double {
        let sorted = route.sorted { $0.timestamp < $1.timestamp }
        return zip(sorted, sorted.dropFirst()).reduce(0) { $0 + $1.1.distance(from: $1.0) }
    }

    private static func elevationGain(_ route: [CLLocation]) -> Double {
        var gain: Double = 0
        var last: Double?
        for location in route.sorted(by: { $0.timestamp < $1.timestamp }) where location.verticalAccuracy >= 0 {
            if let last, location.altitude > last { gain += location.altitude - last }
            last = location.altitude
        }
        return gain
    }

    private static func maxSpeed(_ route: [CLLocation]) -> Double? {
        route.map(\.speed).filter { $0 >= 0 }.max()
    }

    private static func trackPoints(route: [CLLocation], heartRate: [HKQuantitySample]) -> [TrackPointPayload] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let hr = heartRate.compactMap { sample -> (Date, Int)? in
            let bpm = Int(sample.quantity.doubleValue(for: unit))
            return bpm > 0 ? (sample.startDate, bpm) : nil
        }
        .sorted { $0.0 < $1.0 }
        let formatter = ISO8601DateFormatter()
        return route.map { location in
            TrackPointPayload(
                timestamp: formatter.string(from: location.timestamp),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                speedMps: location.speed >= 0 ? location.speed : nil,
                heartRateBpm: hr.last(where: { $0.0 <= location.timestamp })?.1,
                cadenceRpm: nil
            )
        }
    }
}
