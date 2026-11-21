import Foundation

/// The period picker on the Stats screen.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, year, all
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All"
        }
    }

    /// Small heading above the big number.
    var heading: String {
        switch self {
        case .week: "LAST 7 DAYS"
        case .month: "LAST 30 DAYS"
        case .year: "LAST 12 MONTHS"
        case .all: "ALL TIME"
        }
    }

    /// Ends the comparison line: "+18% vs previous 7 days". Nil for All (nothing to compare with).
    var comparisonText: String? {
        switch self {
        case .week: "previous 7 days"
        case .month: "previous 30 days"
        case .year: "previous 12 months"
        case .all: nil
        }
    }
}

enum StatsBucketUnit: Equatable {
    case day, month, year
}

/// One bar of the chart: the distance in one day, month or year.
struct StatsBucket: Equatable, Identifiable {
    let start: Date
    let distanceMeters: Double
    var id: Date { start }
}

/// Everything the Stats screen shows for one period. Foundation only, so it runs on Linux.
/// Follows the same rule as `StatsSummary`: sample activities and activities that start after
/// `now` are left out first, so Home, the activity list and Stats cannot disagree.
struct StatsReport: Equatable {
    let period: StatsPeriod
    let entries: [StatsEntry]
    let distanceMeters: Double
    let durationSeconds: Int
    let activityCount: Int
    /// Seconds per km over run, walk, hike and treadmill activities only (a bike or a gym session has no pace).
    let averagePaceSecondsPerKm: Int?
    /// Distance against the period just before, in percent. Nil for All, and when the earlier period had none.
    let distanceChangePercent: Int?
    let bucketUnit: StatsBucketUnit
    let buckets: [StatsBucket]
    let bySport: [SportTotal]

    private static let paceSports: Set<SportType> = [.run, .walk, .hike, .treadmill]

    init(entries allEntries: [StatsEntry], period: StatsPeriod, now: Date, calendar: Calendar) {
        self.period = period
        let valid = allEntries.filter { $0.source != StatsEntry.sampleSource && $0.startedAt <= now }
        let today = calendar.startOfDay(for: now)

        // [start, previousStart) is the period; [previousStart, start) the one before it.
        let start: Date?
        let previousStart: Date?
        switch period {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: today)
            previousStart = calendar.date(byAdding: .day, value: -13, to: today)
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: today)
            previousStart = calendar.date(byAdding: .day, value: -59, to: today)
        case .year:
            let monthStart = Self.monthStart(now, calendar)
            start = calendar.date(byAdding: .month, value: -11, to: monthStart)
            previousStart = calendar.date(byAdding: .month, value: -23, to: monthStart)
        case .all:
            start = nil
            previousStart = nil
        }

        let inPeriod = start.map { s in valid.filter { $0.startedAt >= s } } ?? valid
        entries = inPeriod
        let total = Self.distance(inPeriod)
        distanceMeters = total
        durationSeconds = inPeriod.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        activityCount = inPeriod.count

        let paced = inPeriod.filter { Self.paceSports.contains($0.sport) && ($0.distanceMeters ?? 0) > 0 && ($0.durationSeconds ?? 0) > 0 }
        let pacedMeters = Self.distance(paced)
        let pacedSeconds = paced.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        averagePaceSecondsPerKm = pacedMeters > 0 ? Int((Double(pacedSeconds) / (pacedMeters / 1000)).rounded()) : nil

        if let start, let previousStart {
            let before = Self.distance(valid.filter { $0.startedAt >= previousStart && $0.startedAt < start })
            distanceChangePercent = before > 0 ? Int(((total - before) / before * 100).rounded()) : nil
        } else {
            distanceChangePercent = nil
        }

        bySport = Dictionary(grouping: inPeriod, by: \.sport)
            .map { sport, items in
                SportTotal(
                    sport: sport,
                    distanceMeters: Self.distance(items),
                    durationSeconds: items.reduce(0) { $0 + ($1.durationSeconds ?? 0) },
                    count: items.count,
                    maxHeartRateBpm: items.compactMap(\.maxHeartRateBpm).max()
                )
            }
            .sorted { $0.distanceMeters > $1.distanceMeters }

        let unit: StatsBucketUnit
        var starts: [Date] = []
        switch period {
        case .week, .month:
            unit = .day
            let days = period == .week ? 7 : 30
            starts = (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        case .year:
            unit = .month
            let first = start ?? Self.monthStart(now, calendar)
            starts = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: first) }
        case .all:
            let thisMonth = Self.monthStart(now, calendar)
            let earliest = valid.map(\.startedAt).min().map { Self.monthStart($0, calendar) } ?? thisMonth
            let months = calendar.dateComponents([.month], from: earliest, to: thisMonth).month ?? 0
            if months < 12 {
                unit = .month
                starts = (0...months).compactMap { calendar.date(byAdding: .month, value: $0, to: earliest) }
            } else {
                unit = .year
                let firstYear = calendar.component(.year, from: earliest)
                let thisYear = calendar.component(.year, from: now)
                starts = (firstYear...thisYear).compactMap { calendar.date(from: DateComponents(year: $0, month: 1, day: 1)) }
            }
        }
        bucketUnit = unit
        let component: Calendar.Component = unit == .day ? .day : (unit == .month ? .month : .year)
        buckets = starts.map { bucketStart in
            let bucketTotal = inPeriod
                .filter { calendar.isDate($0.startedAt, equalTo: bucketStart, toGranularity: component) }
                .reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) }
            return StatsBucket(start: bucketStart, distanceMeters: bucketTotal)
        }
    }

    private static func distance(_ items: [StatsEntry]) -> Double {
        items.reduce(0.0) { $0 + Double($1.distanceMeters ?? 0) }
    }

    private static func monthStart(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
}
