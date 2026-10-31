import SwiftUI

struct HomeDashboardView: View {
    @Environment(ActivitiesStore.self) private var store
    @Environment(\.brandTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    let onRecord: (SportType) -> Void

    var body: some View {
        let summary = HomeSummary(activities: store.activities, now: now, calendar: .current)
        NavigationStack {
            List {
                Section {
                    Text("Make your move")
                        .font(.largeTitle.bold())
                    Text("Choose a sport and make time for yourself.")
                        .foregroundStyle(theme.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                        ForEach(SportType.allCases) { sport in
                            Button { onRecord(sport) } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: sport.symbolName).font(.title2)
                                    Text(sport.label).font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .foregroundStyle(theme.onAccent)
                                .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Record \(sport.label)")
                            .accessibilityIdentifier("home-record-" + sport.rawValue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(theme.surface)

                if store.isLoading {
                    ProgressView("Loading activities")
                        .listRowBackground(theme.surface)
                } else if let error = store.errorMessage {
                    Section {
                        ContentUnavailableView {
                            Label("Couldn't load activities", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Retry") { refresh() }
                                .accessibilityIdentifier("home-retry")
                        }
                    }
                    .listRowBackground(theme.surface)
                } else {
                    Section("Last 7 days") {
                        LabeledContent("Distance", value: Formatters.distance(meters: summary.weeklyDistanceMeters))
                        LabeledContent("Time", value: Formatters.duration(seconds: summary.weeklyDurationSeconds))
                        LabeledContent("Activities", value: "\(summary.weeklyCount)")
                    }
                    .listRowBackground(theme.surface)

                    Section("Recent activities") {
                        if summary.recentActivities.isEmpty {
                            ContentUnavailableView(
                                "No personal activities yet",
                                systemImage: "figure.run",
                                description: Text("Record an activity to see your progress here. Sample activities stay in Activities.")
                            )
                        } else {
                            ForEach(summary.recentActivities) { activity in
                                NavigationLink {
                                    ActivityDetailView(activity: activity)
                                } label: {
                                    recentActivity(activity)
                                }
                            }
                        }
                    }
                    .listRowBackground(theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Home")
            .onAppear { now = Date() }
            .refreshable { refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            now = Date()
        }
    }

    private func refresh() {
        now = Date()
        store.refresh()
    }

    private func recentActivity(_ activity: CDActivity) -> some View {
        let name = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return HStack(spacing: 12) {
            Image(systemName: activity.sportType.symbolName)
                .font(.title2)
                .foregroundStyle(theme.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? activity.sportType.label : name)
                    .font(.headline)
                Text(Formatters.displayDate(date: activity.startedAt))
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                Text("\(Formatters.distance(meters: activity.distanceMeters.map(Double.init))) · \(Formatters.duration(seconds: activity.durationSeconds))")
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}
