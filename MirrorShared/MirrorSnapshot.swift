import Foundation

/// What the iPhone tells the Apple Watch about the recording in progress.
///
/// Pure logic on purpose (Foundation only): it is shared by the iPhone and the
/// watch app, and its tests run on Linux. The transport (WatchConnectivity) is
/// not here; it only moves the dictionary this type produces.
struct MirrorSnapshot: Equatable {
    enum State: String {
        case idle, recording, paused
    }

    var state: State
    /// Active time in whole seconds, pauses excluded (the iPhone timer).
    var elapsedSeconds: Int
    var distanceMeters: Double
    var speedMetersPerSecond: Double
    /// Sport label already localised on the iPhone, e.g. "Run".
    var sportLabel: String
    /// True when the sport shows pace (min/km) rather than speed (km/h).
    var usesPace: Bool

    static let idle = MirrorSnapshot(
        state: .idle, elapsedSeconds: 0, distanceMeters: 0,
        speedMetersPerSecond: 0, sportLabel: "", usesPace: true
    )

    private enum Key {
        static let state = "state"
        static let elapsed = "elapsed"
        static let distance = "distance"
        static let speed = "speed"
        static let sport = "sport"
        static let usesPace = "usesPace"
    }

    /// Property-list friendly: WatchConnectivity only accepts these value types.
    var dictionary: [String: Any] {
        [
            Key.state: state.rawValue,
            Key.elapsed: elapsedSeconds,
            Key.distance: distanceMeters,
            Key.speed: speedMetersPerSecond,
            Key.sport: sportLabel,
            Key.usesPace: usesPace,
        ]
    }

    /// Returns nil when the message is incomplete or malformed, so the watch
    /// keeps its last good screen instead of showing garbage.
    init?(dictionary: [String: Any]) {
        guard
            let rawState = dictionary[Key.state] as? String,
            let state = State(rawValue: rawState),
            let elapsed = dictionary[Key.elapsed] as? Int,
            let distance = dictionary[Key.distance] as? Double,
            let speed = dictionary[Key.speed] as? Double,
            let sport = dictionary[Key.sport] as? String,
            let usesPace = dictionary[Key.usesPace] as? Bool,
            elapsed >= 0, distance >= 0, speed >= 0,
            distance.isFinite, speed.isFinite
        else { return nil }
        self.init(
            state: state, elapsedSeconds: elapsed, distanceMeters: distance,
            speedMetersPerSecond: speed, sportLabel: sport, usesPace: usesPace
        )
    }

    init(
        state: State, elapsedSeconds: Int, distanceMeters: Double,
        speedMetersPerSecond: Double, sportLabel: String, usesPace: Bool
    ) {
        self.state = state
        self.elapsedSeconds = elapsedSeconds
        self.distanceMeters = distanceMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.sportLabel = sportLabel
        self.usesPace = usesPace
    }
}
