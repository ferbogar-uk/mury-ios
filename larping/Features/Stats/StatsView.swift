import Charts
import SwiftUI

struct StatsView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(ActivitiesStore.self) private var store

    @State private var period: StatsPeriod = .week
    @State private var selectedDate: Date?

    private var entries: [StatsEntry] {
        store.activities.map {
            StatsEntry(
                startedAt: $0.startedAt, sport: $0.sportType,
                distanceMeters: $0.distanceMeters, durationSeconds: $0.durationSeconds,
                maxHeartRateBpm: $0.maxHeartRateBpm, source: $0.source
            )
        }
    }

    var body: some View {
        let all = entries
        let report = StatsReport(entries: all, period: period, now: Date(), calendar: Calendar.current)
        let summary = StatsSummary(entries: all, now: Date(), calendar: Calendar.current)
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Period", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stats-period")
                    .onChange(of: period) { selectedDate = nil }

                    StatsHero(report: report)

                    if report.activityCount == 0 {
                        ContentUnavailableView(
                            "No activities in this period",
                            systemImage: "chart.bar",
                            description: Text("Record something to see your stats here.")
                        )
                    } else {
                        StatsMetricRow(report: report)
                        StatsChartCard(report: report, selectedDate: $selectedDate)
                        if !report.bySport.isEmpty { StatsSportCard(report: report) }
                    }

                    if summary.allTimeCount > 0 {
                        StatsBestsRow(summary: summary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(theme.canvas)
            .toolbarBackground(theme.navigation, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Stats")
        }
    }
}

private struct StatsHero: View {
    @Environment(\.brandTheme) private var theme
    let report: StatsReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(report.period.heading)
                .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", report.distanceMeters / 1000))
                    .font(MuryTypography.font(.largeTitle, size: 44, weight: .bold).monospacedDigit())
                Text("km")
                    .font(MuryTypography.font(.title3, size: 17, weight: .regular))
                    .foregroundStyle(theme.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("stats-total")
            if let change = report.distanceChangePercent, let against = report.period.comparisonText {
                HStack(spacing: 4) {
                    Text(change > 0 ? "+\(change)%" : "\(change)%")
                        .font(MuryTypography.font(.footnote, size: 13, weight: .bold))
                        .foregroundStyle(change >= 0 ? theme.accent : theme.ink)
                    Text("vs \(against)")
                        .font(MuryTypography.font(.footnote, size: 13, weight: .regular))
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

private struct StatsMetricRow: View {
    let report: StatsReport

    var body: some View {
        HStack(spacing: 8) {
            StatsMetricCard(value: Formatters.duration(seconds: report.durationSeconds), title: "Time")
            StatsMetricCard(value: "\(report.activityCount)", title: report.activityCount == 1 ? "Activity" : "Activities")
            if let pace = report.averagePaceSecondsPerKm {
                StatsMetricCard(value: Formatters.pace(secondsPerKm: pace).replacingOccurrences(of: " /km", with: ""), title: "Avg /km")
            }
        }
    }
}

private struct StatsMetricCard: View {
    @Environment(\.brandTheme) private var theme
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MuryTypography.font(.headline, size: 17, weight: .bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                .foregroundStyle(theme.muted)
        }
        .foregroundStyle(theme.ink)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct StatsChartCard: View {
    @Environment(\.brandTheme) private var theme
    let report: StatsReport
    @Binding var selectedDate: Date?

    private var calendar: Calendar { Calendar.current }

    private var component: Calendar.Component {
        switch report.bucketUnit {
        case .day: .day
        case .month: .month
        case .year: .year
        }
    }

    /// The bar the finger is on, or the biggest one when nothing is touched.
    private var highlighted: StatsBucket? {
        if let selectedDate,
           let touched = report.buckets.first(where: { calendar.isDate(selectedDate, equalTo: $0.start, toGranularity: component) }) {
            return touched
        }
        return report.buckets.max { $0.distanceMeters < $1.distanceMeters }.flatMap { $0.distanceMeters > 0 ? $0 : nil }
    }

    private func title(for bucket: StatsBucket) -> String {
        switch report.bucketUnit {
        case .day: bucket.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .month: bucket.start.formatted(.dateTime.month(.wide).year())
        case .year: bucket.start.formatted(.dateTime.year())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(report.bucketUnit == .day ? "Daily distance" : (report.bucketUnit == .month ? "Monthly distance" : "Yearly distance"))
                    .font(MuryTypography.font(.headline, size: 17, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let bucket = highlighted {
                    Text("\(title(for: bucket)) · \(String(format: "%.1f", bucket.distanceMeters / 1000)) km")
                        .font(MuryTypography.font(.caption, size: 12))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Chart(report.buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.start, unit: component),
                    y: .value("Distance", bucket.distanceMeters / 1000)
                )
                .cornerRadius(4)
                .foregroundStyle(bucket.id == highlighted?.id ? theme.accent : theme.ink)
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                switch report.period {
                case .week:
                    AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) }
                case .month:
                    AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
                case .year:
                    AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.narrow)) }
                case .all:
                    AxisMarks { AxisValueLabel(format: report.bucketUnit == .year ? .dateTime.year() : .dateTime.month(.narrow)) }
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Distance chart")
            .accessibilityValue(highlighted.map { "\(title(for: $0)), \(String(format: "%.1f", $0.distanceMeters / 1000)) kilometres" } ?? "No distance")
        }
        .foregroundStyle(theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatsSportCard: View {
    @Environment(\.brandTheme) private var theme
    let report: StatsReport

    private var longest: Double { report.bySport.map(\.distanceMeters).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By sport")
                .font(MuryTypography.font(.headline, size: 17, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            ForEach(report.bySport) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(entry.sport.label, systemImage: entry.sport.symbolName)
                            .font(MuryTypography.font(.subheadline, size: 15, weight: .regular))
                        Spacer()
                        Text(entry.distanceMeters > 0 ? Formatters.distance(meters: entry.distanceMeters) : Formatters.duration(seconds: entry.durationSeconds))
                            .font(MuryTypography.font(.subheadline, size: 15, weight: .bold).monospacedDigit())
                    }
                    if entry.distanceMeters > 0, longest > 0 {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.border)
                                Capsule().fill(entry.id == report.bySport.first?.id ? theme.accent : theme.ink)
                                    .frame(width: max(6, proxy.size.width * entry.distanceMeters / longest))
                            }
                        }
                        .frame(height: 5)
                        .accessibilityHidden(true)
                    }
                    Text("\(Formatters.duration(seconds: entry.durationSeconds)) · \(entry.count) \(entry.count == 1 ? "activity" : "activities")\(entry.maxHeartRateBpm.map { " · max \($0) bpm" } ?? "")")
                        .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                        .foregroundStyle(theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// All-time personal bests, whatever period is picked above.
private struct StatsBestsRow: View {
    @Environment(\.brandTheme) private var theme
    let summary: StatsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal bests")
                .font(MuryTypography.font(.headline, size: 17, weight: .bold))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 2)
            HStack(spacing: 8) {
                if let best = summary.longestDistance, let distance = best.distanceMeters, distance > 0 {
                    BestCard(title: "Longest", value: Formatters.distance(meters: Double(distance)), entry: best)
                }
                if let best = summary.longestDuration, let duration = best.durationSeconds, duration > 0 {
                    BestCard(title: "Time", value: Formatters.duration(seconds: duration), entry: best)
                }
                if let best = summary.highestHeartRate, let heartRate = best.maxHeartRateBpm, heartRate > 0 {
                    BestCard(title: "Max HR", value: "\(heartRate)", entry: best)
                }
            }
        }
    }
}

private struct BestCard: View {
    @Environment(\.brandTheme) private var theme
    let title: String
    let value: String
    let entry: StatsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(MuryTypography.font(.caption2, size: 10, weight: .regular))
                .tracking(0.6)
                .foregroundStyle(theme.muted)
            Text(value)
                .font(MuryTypography.font(.headline, size: 17, weight: .bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(entry.sport.label) · \(entry.startedAt.formatted(.dateTime.day().month(.abbreviated)))")
                .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(theme.ink)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
