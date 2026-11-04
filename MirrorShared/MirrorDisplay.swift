import Foundation

/// The three lines the watch shows, formatted exactly like the iPhone does.
///
/// Self-contained on purpose: the watch app compiles this file together with
/// MirrorSnapshot.swift and nothing else, so it cannot use `Formatters` (which
/// also knows about iPhone-only types). MirrorDisplayTests checks the output
/// against `Formatters` so the two never drift apart.
struct MirrorDisplay: Equatable {
    let time: String
    let distance: String
    /// Pace ("5:30 /km") or speed ("24.0 km/h") depending on the sport.
    let rate: String
    let isPaused: Bool

    private static let dash = "\u{2013}"

    init(_ snapshot: MirrorSnapshot) {
        time = Self.duration(seconds: snapshot.elapsedSeconds)
        distance = String(format: "%.2f km", snapshot.distanceMeters / 1000)
        rate = snapshot.usesPace
            ? Self.pace(fromSpeed: snapshot.speedMetersPerSecond)
            : Self.speed(snapshot.speedMetersPerSecond)
        isPaused = snapshot.state == .paused
    }

    private static func duration(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private static func pace(fromSpeed metersPerSecond: Double) -> String {
        guard metersPerSecond > 0.1 else { return dash }
        let secondsPerKm = Int(1000 / metersPerSecond)
        guard secondsPerKm > 0 else { return dash }
        return String(format: "%d:%02d /km", secondsPerKm / 60, secondsPerKm % 60)
    }

    private static func speed(_ metersPerSecond: Double) -> String {
        guard metersPerSecond > 0.1 else { return dash }
        return String(format: "%.1f km/h", metersPerSecond * 3.6)
    }
}
