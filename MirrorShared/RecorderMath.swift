import Foundation

/// One GPS fix, reduced to the numbers the recorder's maths needs.
///
/// Foundation only, so the arithmetic below runs on Linux. LocationTracker turns
/// each CLLocation into one of these and hands it to `RecorderMath`.
struct GPSFix: Equatable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    /// Metres. Negative means the fix is invalid, as in CLLocation.
    var horizontalAccuracy: Double
    /// Metres. Negative means the altitude is not trustworthy.
    var verticalAccuracy: Double
    /// Metres per second. Negative means unknown.
    var speed: Double
}

/// The running totals of a recording, and the rule for folding a new fix in.
///
/// This is the same arithmetic LocationTracker used inline. RecorderMathTests
/// pins the behaviour so moving it did not change any recorded number.
struct RecorderMath: Equatable {
    /// Fixes at or above this horizontal accuracy (metres) are treated as a bad signal.
    static let degradedAccuracyMeters = 50.0

    private(set) var distanceMeters = 0.0
    private(set) var currentSpeedMps = 0.0
    private(set) var maxSpeedMps = 0.0
    private(set) var elevationGainMeters = 0.0
    private(set) var isGPSDegraded = false

    private var lastFix: GPSFix?
    private var lastAltitude: Double?

    /// What to do with the point after `add` ran.
    enum Outcome: Equatable {
        /// The fix counts: keep it on the route and in the stored track points.
        case accepted
        /// Not recording, or the signal is too weak: nothing was kept.
        case ignored
    }

    /// Folds one fix into the totals. `isRecording` is false while idle or paused.
    mutating func add(_ fix: GPSFix, isRecording: Bool) -> Outcome {
        isGPSDegraded = fix.horizontalAccuracy < 0 || fix.horizontalAccuracy >= Self.degradedAccuracyMeters
        guard isRecording, !isGPSDegraded else { return .ignored }

        if let lastFix {
            distanceMeters += GeoDistance.meters(
                fromLatitude: lastFix.latitude, longitude: lastFix.longitude,
                toLatitude: fix.latitude, longitude: fix.longitude
            )
        }
        lastFix = fix
        currentSpeedMps = max(fix.speed, 0)
        maxSpeedMps = max(maxSpeedMps, currentSpeedMps)

        if fix.verticalAccuracy >= 0 {
            if let lastAltitude, fix.altitude > lastAltitude {
                elevationGainMeters += fix.altitude - lastAltitude
            }
            lastAltitude = fix.altitude
        }
        return .accepted
    }
}
