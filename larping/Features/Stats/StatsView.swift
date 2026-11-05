import Charts
import SwiftUI

struct StatsView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(ActivitiesStore.self) private var store

    private var summary: StatsSummary {
        StatsSummary(
            entries: store.activities.map {
                StatsEntry(
                    startedAt: $0.startedAt, sport: $0.sportType,
                    distanceMeters: $0.distanceMeters, durationSeconds: $0.durationSeconds,
                    maxHeartRateBpm: $0.maxHeartRateBpm
                )
            },
            now: Date(), calendar: Calendar.current
        )
    }

    var body: some View {
        let s = summary
        return NavigationStack {
            List {
                Section {
                    HStack {
                        StatColumn(title: "Distance", value: Formatters.distance(meters: s.weekDistance))
                        StatColumn(title: "Time", value: Formatters.duration(seconds: s.weekDuration))
                        StatColumn(title: "Activities", value: "\(s.lastWeek.count)")
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Daily distance") {
                    Chart(s.dailyDistance) { entry in
                        BarMark(
                            x: .value("Day", entry.day, unit: .day),
                            y: .value("Distance", entry.distanceMeters / 1000)
                        )
                        .foregroundStyle(theme.tint)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }

                if !s.bySport.isEmpty {
                    Section("By sport this week") {
                        ForEach(s.bySport) { entry in
                            HStack {
                                Label(entry.sport.label, systemImage: entry.sport.symbolName)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formatters.distance(meters: entry.distanceMeters))
                                        .foregroundStyle(.secondary)
                                    Text("\(Formatters.duration(seconds: entry.durationSeconds)) · \(entry.count) \(entry.count == 1 ? "activity" : "activities")\(entry.maxHeartRateBpm.map { " · max \($0) bpm" } ?? "")")
                                        .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if s.lastWeek.isEmpty {
                    ContentUnavailableView(
                        "No activities this week",
                        systemImage: "chart.bar",
                        description: Text("Record something to see your weekly stats here.")
                    )
                }

                if s.allTimeCount > 0 {
                    Section("All time") {
                        HStack {
                            StatColumn(title: "Distance", value: Formatters.distance(meters: s.allTimeDistance))
                            StatColumn(title: "Time", value: Formatters.duration(seconds: s.allTimeDuration))
                            StatColumn(title: "Activities", value: "\(s.allTimeCount)")
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Personal bests") {
                        if let best = s.longestDistance, let distance = best.distanceMeters {
                            BestRow(
                                title: "Longest distance",
                                sport: best.sport,
                                value: Formatters.distance(meters: Double(distance))
                            )
                        }
                        if let best = s.longestDuration, let duration = best.durationSeconds {
                            BestRow(
                                title: "Longest duration",
                                sport: best.sport,
                                value: Formatters.duration(seconds: duration)
                            )
                        }
                        if let best = s.highestHeartRate, let heartRate = best.maxHeartRateBpm {
                            BestRow(
                                title: "Highest heart rate",
                                sport: best.sport,
                                value: "\(heartRate) bpm"
                            )
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .toolbarBackground(theme.navigation, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Stats")
        }
    }
}

private struct BestRow: View {
    let title: String
    let sport: SportType
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: sport.symbolName)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

private struct StatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(MuryTypography.font(.title3, size: 20, weight: .bold).monospacedDigit())
            Text(title.uppercased()).font(MuryTypography.font(.caption2, size: 11, weight: .regular)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}