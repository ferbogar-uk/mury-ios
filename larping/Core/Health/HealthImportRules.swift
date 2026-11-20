import Foundation

/// A workout in Apple Health, reduced to what the import decision needs.
nonisolated struct HealthWorkoutRecord: Equatable {
    let externalID: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    /// True for workouts MURY itself wrote to Health (they carry `larping.activityID`).
    let writtenByMury: Bool
}

/// An activity MURY already holds that came from Health (or an earlier manual import).
nonisolated struct ExistingImport: Equatable {
    let externalID: String?
    let startedAt: Date
}

/// Decides which Health workouts to import. Pure so it is tested without HealthKit.
nonisolated enum HealthImportRules {
    /// Bumped when the Health-to-MURY type mapping widens; older imports are then looked at again.
    static let sportMappingVersion = 2

    /// A Health import saved as "Other" may now have a proper type (phase 2 widened the list).
    static func needsReclassifying(sport: SportType, source: String, externalID: String?) -> Bool {
        sport == .other && source == "healthkit_import" && UUID(uuidString: externalID ?? "") != nil
    }

    static let backfillDays = 90
    /// Manual imports made before ids were stored match by start time within this many seconds.
    static let sameStartToleranceSeconds: TimeInterval = 60
    static let syncThrottleSeconds: TimeInterval = 600

    static func select(
        _ records: [HealthWorkoutRecord],
        existing: [ExistingImport],
        now: Date,
        days: Int = backfillDays
    ) -> [HealthWorkoutRecord] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return records
            .filter { record in
                guard !record.writtenByMury,
                      record.durationSeconds > 0,
                      record.startedAt >= cutoff else { return false }
                return !existing.contains { item in
                    if let id = item.externalID, id == record.externalID { return true }
                    return abs(item.startedAt.timeIntervalSince(record.startedAt)) < sameStartToleranceSeconds
                }
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Foreground sync runs at most once every ten minutes.
    static func shouldSync(last: Date?, now: Date) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= syncThrottleSeconds
    }
}
