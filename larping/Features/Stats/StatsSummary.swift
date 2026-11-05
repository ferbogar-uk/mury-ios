import Foundation

/// One activity reduced to what the statistics need. Foundation only.
///
/// StatsView turns each stored activity into one of these, so the arithmetic
/// below runs on Linux and is tested with fixed dates.
struct StatsEntry: Equatable {
    var startedAt: Date
    var sport: SportType
    var distanceMeters: Int?
    var durationSeconds: Int?
    var maxHeartRateBpm: Int?
    /// Where the activity came from ("mobile", "gpx_import", "healthkit_import",
    /// "sample"). Sample activities are demo data and never count.
    var source: String = "mobile"

    static let sampleSource = "sample"
}

struct DayTotal: Equatable, Identifiable {
    let day: Date
    let distanceMeters: Double
    var id: Date { day }
}

struct SportTotal: Equatable, Identifiable {
    let sport: SportType
    let distanceMeters: Double
    let durationSeconds: Int
    let count: Int
    let maxHeartRateBpm: Int?
    var id: SportType { sport }
}

/// The numbers on the Stats screen. `now` and `calendar` are parameters so the
/// results do not depend on the day the tests run.
struct StatsSummary: Equatable {
    let lastWeek: [StatsEntry]
    let dailyDistance: [DayTotal]
    let bySport: [SportTotal]
    let weekDistance: Double
    let weekDuration: Int
    let allTimeDistance: Double
    let allTimeDuration: Int
    let allTimeCount: Int
    let longestDistance: StatsEntry?
    let longestDuration: StatsEntry?
    let highestHeartRate: StatsEntry?

    /// Every screen that shows a week or a total uses this one rule: sample
    /// activities and activities that start after `now` are left out first, so
    /// Home, the activity list and Stats can never disagree.
    init(entries allEntries: [StatsEntry], now: Date, calendar: Calendar) {
        let entries = allEntries.filter { $0.source != StatsEntry.sampleSource && $0.startedAt <= now }
        let today = calendar.startOfDay(for: now)
        // The last seven days including today.
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today)!
        let week = entries.filter { $0.startedAt >= cutoff }
        lastWeek = week

        let days = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }.reversed()
        dailyDistance = days.map { day in
            let total = week
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) }
            return DayTotal(day: day, distanceMeters: total)
        }

        bySport = Dictionary(grouping: week, by: \.sport)
            .map { sport, items in
                SportTotal(
                    sport: sport,
                    distanceMeters: items.reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) },
                    durationSeconds: items.reduce(0) { $0 + ($1.durationSeconds ?? 0) },
                    count: items.count,
                    maxHeartRateBpm: items.compactMap(\.maxHeartRateBpm).max()
                )
            }
            .sorted { $0.distanceMeters > $1.distanceMeters }

        weekDistance = week.reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) }
        weekDuration = week.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        allTimeDistance = entries.reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) }
        allTimeDuration = entries.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        allTimeCount = entries.count
        longestDistance = entries.max { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
        longestDuration = entries.max { ($0.durationSeconds ?? 0) < ($1.durationSeconds ?? 0) }
        highestHeartRate = entries.max { ($0.maxHeartRateBpm ?? 0) < ($1.maxHeartRateBpm ?? 0) }
    }
}
