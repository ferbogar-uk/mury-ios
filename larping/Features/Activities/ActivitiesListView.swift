import SwiftData
import SwiftUI

struct ActivitiesListView: View {
    @Environment(\.brandTheme) private var theme
    @Query(sort: \CDActivity.startedAt, order: .reverse) private var activities: [CDActivity]
    @State private var showGPXImport = false
    @State private var showHealthImport = false

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// The same week rule as Home and Stats: sample and future activities are left out.
    private var week: StatsSummary {
        StatsSummary(entries: activities.map(\.statsEntry), now: Date(), calendar: Calendar.current)
    }

    private var monthSections: [(month: String, activities: [CDActivity])] {
        MonthGrouping.sections(activities, date: \.startedAt, calendar: Calendar.current)
            .map { (month: Self.monthFormatter.string(from: $0.month), activities: $0.items) }
    }

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(theme.canvas)
                .toolbarBackground(theme.navigation, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Image("LogoHorizontal")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 22)
                            .accessibilityLabel("MURY")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showGPXImport = true
                            } label: {
                                Label("Import GPX", systemImage: "map")
                            }
                            if HealthKitService.isAvailable {
                                Button {
                                    showHealthImport = true
                                } label: {
                                    Label("Import from Health", systemImage: "heart")
                                }
                            }
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                    }
                }
                .sheet(isPresented: $showGPXImport) {
                    ImportGPXView()
                }
                .sheet(isPresented: $showHealthImport) {
                    ImportHealthKitView()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if activities.isEmpty {
            ContentUnavailableView(
                "No activities yet",
                systemImage: "figure.run",
                description: Text("Record your first run, ride, or hike from the Record tab.")
            )
        } else {
            let week = week
            List {
                Section {
                    HStack {
                        WeekStatColumn(title: "Distance", value: Formatters.distance(meters: week.weekDistance))
                        WeekStatColumn(title: "Time", value: Formatters.duration(seconds: week.weekDuration))
                        WeekStatColumn(title: "Activities", value: "\(week.lastWeek.count)")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("This week")
                }

                ForEach(monthSections, id: \.month) { section in
                    Section(section.month) {
                        ForEach(section.activities) { activity in
                            NavigationLink(value: activity.id) {
                                ActivityRow(activity: activity)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: UUID.self) { id in
                if let activity = activities.first(where: { $0.id == id }) {
                    ActivityDetailView(activity: activity)
                }
            }
        }
    }
}

private struct WeekStatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(MuryTypography.font(.subheadline, size: 15, weight: .bold).monospacedDigit())
            Text(title.uppercased()).font(MuryTypography.font(.caption2, size: 11, weight: .regular)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActivityRow: View {
    let activity: CDActivity

    private var title: String {
        let trimmed = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? activity.sportType.label : trimmed
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.sportType.symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(Formatters.displayDate(date: activity.startedAt))
                    .font(MuryTypography.font(.caption, size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.distance(meters: activity.distanceMeters.map(Double.init)))
                    .font(MuryTypography.font(.subheadline, size: 15, weight: .regular).monospacedDigit())
                Text("\(Formatters.duration(seconds: activity.durationSeconds)) · \(Formatters.paceOrSpeed(sportType: activity.sportType, averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm, averageSpeedMps: activity.averageSpeedMps))")
                    .font(MuryTypography.font(.caption, size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}