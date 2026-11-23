import Foundation

/// Picks the (up to) three rows a share card shows. A run keeps distance /
/// duration / pace; an activity with no distance or pace (strength, yoga…)
/// drops those empty rows and fills the space with heart rate instead.
/// Foundation-only so it is also tested on Linux CI.
enum ShareStatRows {
    struct Row: Equatable {
        let label: String
        let value: String
    }

    static let emptyValue = "–"
    static let maxRows = 3

    static func rows(distance: String, duration: String, metricLabel: String, paceOrSpeed: String,
                     averageHeartRate: String, maxHeartRate: String) -> [Row] {
        let candidates = [
            Row(label: "DISTANCE", value: distance),
            Row(label: "DURATION", value: duration),
            Row(label: metricLabel, value: paceOrSpeed),
            Row(label: "AVG HEART RATE", value: averageHeartRate),
            Row(label: "MAX HEART RATE", value: maxHeartRate),
        ]
        let filled = candidates.filter { !$0.value.isEmpty && $0.value != emptyValue }
        // Duration is always shown, even when it is the only value.
        guard !filled.isEmpty else { return [candidates[1]] }
        return Array(filled.prefix(maxRows))
    }

    static func heartRateText(_ bpm: Int?) -> String {
        guard let bpm, bpm > 0 else { return emptyValue }
        return "\(bpm) bpm"
    }
}
