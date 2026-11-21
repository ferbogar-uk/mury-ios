import Foundation

/// Every kind of activity MURY knows (phase 2: the wide Apple Exercise list).
/// Raw values are stored in SwiftData and backups, so existing ones never change.
nonisolated enum SportType: String, Codable, CaseIterable, Identifiable {
    // Outdoor, with GPS and a map.
    case run, walk, hike, ride, swim, rowing, tennis, football
    // Indoor and gym, no route: time, heart rate, calories.
    case strength, treadmill, indoorCycle, stairs, elliptical, hiit, yoga, pilates, core, dance, climbing, indoorRow, boxing
    case other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
        case .hike: "Hike"
        case .ride: "Ride"
        case .swim: "Swim"
        case .rowing: "Rowing"
        case .tennis: "Tennis"
        case .football: "Football"
        case .strength: "Strength"
        case .treadmill: "Treadmill"
        case .indoorCycle: "Indoor cycle"
        case .stairs: "Stairs"
        case .elliptical: "Elliptical"
        case .hiit: "HIIT"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .core: "Core"
        case .dance: "Dance"
        case .climbing: "Climbing"
        case .indoorRow: "Indoor row"
        case .boxing: "Boxing"
        case .other: "Other"
        }
    }

    /// SF Symbols, the same figures Apple's Exercise app uses.
    var symbolName: String {
        switch self {
        case .run: "figure.run"
        case .walk: "figure.walk"
        case .hike: "figure.hiking"
        case .ride: "figure.outdoor.cycle"
        case .swim: "figure.pool.swim"
        case .rowing: "figure.outdoor.rowing"
        case .tennis: "figure.tennis"
        case .football: "figure.soccer"
        case .strength: "mury.strength" // custom icon, drawn by SportIcon (not an SF Symbol)
        case .treadmill: "figure.run.treadmill"
        case .indoorCycle: "figure.indoor.cycle"
        case .stairs: "figure.stair.stepper"
        case .elliptical: "figure.elliptical"
        case .hiit: "figure.highintensity.intervaltraining"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .core: "figure.core.training"
        case .dance: "figure.dance"
        case .climbing: "figure.climbing"
        case .indoorRow: "figure.indoor.rowing"
        case .boxing: "figure.boxing"
        case .other: "figure.mixed.cardio"
        }
    }

    /// Running/walking/hiking/swimming (and treadmill) read naturally as pace (min/km);
    /// cycling and everything else read naturally as speed (km/h).
    var usesPaceMetric: Bool {
        switch self {
        case .run, .walk, .hike, .swim, .treadmill: true
        default: false
        }
    }

    /// Indoor and gym activities have no route; they show time, heart rate and calories.
    var isIndoor: Bool {
        switch self {
        case .strength, .treadmill, .indoorCycle, .stairs, .elliptical, .hiit, .yoga, .pilates,
             .core, .dance, .climbing, .indoorRow, .boxing: true
        default: false
        }
    }

    /// What the GPS recorder can record today. Indoor recording on the iPhone is phase 7,
    /// so indoor types only arrive from Health for now.
    static var recordable: [SportType] { allCases.filter { !$0.isIndoor } }
}

/// Builds the default event title for an activity: "Larping Run", bumped to
/// "Larping Run 1" / "Larping Run 2" / … as soon as a name already exists, so
/// recording the same sport repeatedly never produces duplicates.
nonisolated enum EventNamer {
    static func nextName(base: String, existing: [String]) -> String {
        var maxSuffix = -1
        if existing.contains(base) { maxSuffix = 0 }
        let prefix = base + " "
        for name in existing where name.hasPrefix(prefix) {
            if let n = Int(name.dropFirst(prefix.count)) {
                maxSuffix = max(maxSuffix, n)
            }
        }
        return maxSuffix < 0 ? base : "\(base) \(maxSuffix + 1)"
    }
}

/// In-memory transfer shape produced by the live recorder and GPX import and
/// consumed by `ActivitiesStore` when materializing SwiftData track points.
nonisolated struct TrackPointPayload: Codable {
    let timestamp: String
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let speedMps: Double?
    let heartRateBpm: Int?
    let cadenceRpm: Int?
}