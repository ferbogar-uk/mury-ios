import Foundation

/// What the bottom card of a flyover / cinema video says: who ran, what the activity was and its headline numbers.
/// Plain text prepared once, so the live screens, the in-app renderer and the screen-recorded Map cinema all show the
/// same card.
nonisolated struct VideoOverlayInfo: Sendable, Equatable {
    let athleteName: String
    let activityTitle: String
    let symbolName: String
    let distance: String
    let paceLabel: String
    let pace: String
    let elevation: String

    /// Up to two initials for the round avatar.
    var initials: String {
        let letters = athleteName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "M" : String(letters).uppercased()
    }

    @MainActor
    static func make(activity: CDActivity, athleteName: String) -> VideoOverlayInfo {
        let trimmedName = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VideoOverlayInfo(
            athleteName: trimmedName.isEmpty ? "MURY User" : trimmedName,
            activityTitle: event.isEmpty ? activity.sportType.label : event,
            symbolName: activity.sportType.symbolName,
            distance: Formatters.distance(meters: activity.distanceMeters.map(Double.init)),
            paceLabel: activity.sportType.usesPaceMetric ? "Pace" : "Speed",
            pace: Formatters.paceOrSpeed(sportType: activity.sportType,
                                         averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
                                         averageSpeedMps: activity.averageSpeedMps),
            elevation: Formatters.elevation(meters: activity.elevationGainMeters.map(Double.init)))
    }
}
