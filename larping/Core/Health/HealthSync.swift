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
    static let mappingVersionKey = "healthSportMappingVersion"
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
        if UserDefaults.standard.integer(forKey: mappingVersionKey) < HealthImportRules.sportMappingVersion,
           await reclassify(store: store) {
            UserDefaults.standard.set(HealthImportRules.sportMappingVersion, forKey: mappingVersionKey)
        }

        let byID = Dictionary(workouts.map { ($0.uuid.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        let records = workouts.map(record(from:))
        let selected = HealthImportRules.select(records, existing: store.existingImports(), now: now, days: days)

        var result = HealthSyncResult(skipped: workouts.count - selected.count)
        for item in selected {
            guard let workout = byID[item.externalID] else { continue }
            do {
                try await importOne(workout, sport: SportType(workout: workout), store: store)
                result.imported += 1
            } catch {
                result.failed += 1
            }
        }
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        return result
    }

    /// Gives older "Other" imports their proper type from Health. True when it finished.
    static func reclassify(store: ActivitiesStore) async -> Bool {
        let candidates = store.activities.filter {
            HealthImportRules.needsReclassifying(sport: $0.sportType, source: $0.source, externalID: $0.externalID)
        }
        guard !candidates.isEmpty else { return true }
        let ids = candidates.compactMap { $0.externalID.flatMap(UUID.init(uuidString:)) }
        // Nothing back (Health not reachable or not allowed yet): try again on a later sync.
        guard let workouts = try? await HealthKitService.fetchWorkouts(ids: ids), !workouts.isEmpty else { return false }
        let byID = Dictionary(workouts.map { ($0.uuid.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        var ok = true
        for activity in candidates {
            guard let id = activity.externalID, let workout = byID[id] else { continue }
            let sport = SportType(workout: workout)
            guard sport != .other else { continue }
            var heartRate: [HeartRateSample] = []
            if sport.isIndoor { heartRate = samples(await HealthKitService.heartRateSamples(for: workout)) }
            do {
                try store.updateFromHealth(activity, sport: sport, energyKcal: energy(workout), heartRate: heartRate)
            } catch { ok = false }
        }
        return ok
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
            energyKcal: energy(workout),
            heartRate: samples(heartRate),
            trackPointsPayloads: trackPoints(route: route, heartRate: heartRate)
        )
    }

    /// Active energy Health measured for the workout, in kcal.
    static func energy(_ workout: HKWorkout) -> Int? {
        guard let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()), kcal >= 1 else { return nil }
        return Int(kcal.rounded())
    }

    private static func samples(_ heartRate: [HKQuantitySample]) -> [HeartRateSample] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        return heartRate.map { HeartRateSample(timestamp: $0.startDate, bpm: Int($0.quantity.doubleValue(for: unit))) }
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
