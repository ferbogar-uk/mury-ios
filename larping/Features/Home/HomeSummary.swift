import Foundation

struct HomeSummary {
    let weeklyDistanceMeters: Double
    let weeklyDurationSeconds: Int
    let weeklyCount: Int
    let recentActivities: [CDActivity]

    init(activities: [CDActivity], now: Date, calendar: Calendar) {
        let personalActivities = activities.filter { $0.source != "sample" && $0.startedAt <= now }
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let week = personalActivities.filter { $0.startedAt >= start }
        weeklyDistanceMeters = week.reduce(0) { $0 + Double($1.distanceMeters ?? 0) }
        weeklyDurationSeconds = week.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        weeklyCount = week.count
        recentActivities = Array(personalActivities.sorted { $0.startedAt > $1.startedAt }.prefix(3))
    }
}
