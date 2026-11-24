import Foundation

/// The (up to) three numbers an activity card shows. With a distance it is the familiar
/// Distance / Time / Avg HR-or-pace; without one (strength, yoga…) the empty Distance is
/// dropped and the card shows Time plus whatever the activity measured: average heart
/// rate, calories, max heart rate. Foundation-only, so it is also tested on Linux CI.
enum ActivityCardStats {
    struct Item: Equatable {
        let label: String
        let value: String
    }

    static let maxItems = 3

    static func items(distanceText: String?, durationText: String, paceLabel: String, paceText: String?,
                      averageHeartRate: Int?, maxHeartRate: Int?, calories: Int?) -> [Item] {
        let time = Item(label: "Time", value: durationText)
        let avgHR = averageHeartRate.flatMap { $0 > 0 ? Item(label: "Avg HR", value: "\($0)") : nil }
        let maxHR = maxHeartRate.flatMap { $0 > 0 ? Item(label: "Max HR", value: "\($0)") : nil }
        let kcal = calories.flatMap { $0 > 0 ? Item(label: "Calories", value: "\($0) kcal") : nil }

        if let distanceText {
            let third = avgHR ?? paceText.map { Item(label: paceLabel, value: $0) }
            return [Item(label: "Distance", value: distanceText), time] + (third.map { [$0] } ?? [])
        }
        let items = [time] + [avgHR, kcal, maxHR].compactMap { $0 }
        return Array(items.prefix(maxItems))
    }
}
