import Foundation

/// Decisions behind the Activities list (filters, month headers), kept free of SwiftUI
/// so they run in the Linux tests.
enum ActivityListRules {
    /// Totals shown on a month header.
    struct MonthTotal: Equatable {
        var distanceMeters: Double = 0
        var durationSeconds = 0
        var count = 0
    }

    /// Sports that appear in the list, most used first (ties in the app's own order).
    /// Only these get a filter chip.
    static func sports(in entries: [StatsEntry]) -> [SportType] {
        let counts = Dictionary(grouping: entries, by: \.sport).mapValues(\.count)
        let order = Dictionary(uniqueKeysWithValues: SportType.allCases.enumerated().map { ($1, $0) })
        return counts.keys.sorted {
            counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : order[$0]! < order[$1]!
        }
    }

    /// Everything when no sport is chosen, otherwise just that sport.
    static func matches(_ entry: StatsEntry, sport: SportType?) -> Bool {
        sport == nil || entry.sport == sport
    }

    static func total(_ entries: [StatsEntry]) -> MonthTotal {
        entries.reduce(into: MonthTotal()) { total, entry in
            total.distanceMeters += Double(entry.distanceMeters ?? 0)
            total.durationSeconds += entry.durationSeconds ?? 0
            total.count += 1
        }
    }

    /// "November" for months of the current year, "October 2025" otherwise.
    static func monthTitle(_ month: Date, now: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        let sameYear = calendar.component(.year, from: month) == calendar.component(.year, from: now)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "LLLL" : "LLLL yyyy")
        return formatter.string(from: month)
    }

    /// "9 activities", "1 activity".
    static func countLabel(_ count: Int) -> String {
        count == 1 ? "1 activity" : "\(count) activities"
    }
}
