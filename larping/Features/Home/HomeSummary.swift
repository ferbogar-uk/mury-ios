import Foundation

struct HomeSummary {
    let weeklyDistanceMeters: Double
    let weeklyDurationSeconds: Int
    let weeklyCount: Int
    let recentActivities: [CDActivity]
    /// The last seven days, oldest first, for the Home week strip.
    let dailyDistance: [DayTotal]

    init(activities: [CDActivity], now: Date, calendar: Calendar) {
        let personalActivities = activities.filter { $0.source != StatsEntry.sampleSource && $0.startedAt <= now }
        // The week numbers come from the one shared rule in StatsSummary.
        let week = StatsSummary(entries: activities.map(\.statsEntry), now: now, calendar: calendar)
        weeklyDistanceMeters = week.weekDistance
        weeklyDurationSeconds = week.weekDuration
        weeklyCount = week.lastWeek.count
        dailyDistance = week.dailyDistance
        recentActivities = Array(personalActivities.sorted { $0.startedAt > $1.startedAt }.prefix(3))
    }
}
