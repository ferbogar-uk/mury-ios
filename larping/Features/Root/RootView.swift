import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var activitiesStore: ActivitiesStore?
    @State private var tracker = LocationTracker()
    /// Set when the watch asks to finish. The Record tab shows the confirmation;
    /// nothing is saved until it is confirmed on the iPhone.
    @State private var finishRequestedFromWatch = false

    private enum AppTab: Hashable { case home, activities, record, stats, profile }
    @State private var selectedTab = AppTab.home
    @State private var requestedSport = SportType.run
    @State private var recordRequestID: UUID?
    @State private var renderReport: RenderReport?

    var body: some View {
        Group {
            if let activitiesStore {
                TabView(selection: $selectedTab) {
                    Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                        HomeDashboardView { sport in
                            requestedSport = sport
                            recordRequestID = UUID()
                            selectedTab = .record
                        }
                    }
                    Tab("Activities", systemImage: "list.bullet", value: AppTab.activities) {
                        ActivitiesListView()
                    }
                    Tab("Record", systemImage: "record.circle", value: AppTab.record) {
                        RecordView(initialSport: requestedSport, requestID: recordRequestID)
                    }
                    Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
                        StatsView()
                    }
                    Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                        ProfileView()
                    }
                }
                .environment(activitiesStore)
                .environment(tracker)
                .environment(\.finishRequestedFromWatch, $finishRequestedFromWatch)
                .toolbarBackground(theme.navigation, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                ProgressView()
            }
        }
        .sheet(item: $renderReport) { report in
            RenderReportView(report: report) {
                RenderCrashLog.shared.dismiss()
                renderReport = nil
            }
        }
        .onAppear {
            if renderReport == nil { renderReport = RenderReport.pending() }
            WatchMirror.shared.onCommand = { handleWatchCommand($0) }
            WatchMirror.shared.onRecordingReceived = { importWatchRecordings() }
        }
        .task {
            if activitiesStore == nil {
                SeedData.seedIfNeeded(context: modelContext)
                let store = ActivitiesStore(modelContext: modelContext)
                activitiesStore = store
                store.refresh()
            }
            importWatchRecordings()
        }
    }

    /// Imports the recordings the watch sent, once each. A file leaves the inbox only after
    /// the activity is saved (or was already there), so nothing is lost and nothing doubles.
    private func importWatchRecordings() {
        guard let store = activitiesStore else { return }
        let inbox = WatchMirror.inbox
        for record in inbox.loadAll() {
            let existing = store.activities.map { (source: $0.source, startedAt: $0.startedAt) }
            if WatchImport.isDuplicate(record, existing: existing) {
                inbox.delete(id: record.id)
                continue
            }
            guard let values = WatchImport.values(from: record) else {
                inbox.delete(id: record.id)
                continue
            }
            let hour = Calendar.current.component(.hour, from: values.startedAt)
            let base = ActivityNamer.title(sport: values.sportType, hour: hour, place: nil)
            do {
                let activity = try store.create(
                    sportType: values.sportType, startedAt: values.startedAt, endedAt: values.endedAt,
                    durationSeconds: values.durationSeconds, distanceMeters: values.distanceMeters,
                    elevationGainMeters: values.elevationGainMeters, averageSpeedMps: values.averageSpeedMps,
                    maxSpeedMps: values.maxSpeedMps, source: WatchImport.source,
                    eventName: EventNamer.nextName(base: base, existing: store.activities.compactMap(\.eventName)),
                    trackPointsPayloads: values.trackPoints
                )
                inbox.delete(id: record.id)
                Task { await HealthKitService.saveWorkout(from: activity) }
                nameWithPlace(activity, in: store, sport: values.sportType, hour: hour)
            } catch {
                // Kept in the inbox: the next launch tries again.
            }
        }
    }

    /// Adds the neighbourhood to an automatic title. The place is looked up from the first
    /// route point; with no answer the title stays as it is.
    private func nameWithPlace(_ activity: CDActivity, in store: ActivitiesStore, sport: SportType, hour: Int) {
        guard let first = activity.trackPoints.min(by: { $0.timestamp < $1.timestamp }) else { return }
        let current = activity.eventName
        Task {
            guard let place = await PlaceNamer.name(latitude: first.latitude, longitude: first.longitude),
                  activity.eventName == current else { return }
            let base = ActivityNamer.title(sport: sport, hour: hour, place: place)
            let others = store.activities.filter { $0.id != activity.id }.compactMap(\.eventName)
            try? store.rename(activity, to: EventNamer.nextName(base: base, existing: others))
        }
    }

    /// Applies a command from the watch, with the same rules the tests cover: a command
    /// that does not fit the current state is dropped.
    private func handleWatchCommand(_ command: WatchCommand) {
        let state: MirrorSnapshot.State
        switch tracker.state {
        case .idle: state = .idle
        case .recording: state = .recording
        case .paused: state = .paused
        }
        switch WatchControls.decide(command, in: state) {
        case .pause: tracker.pause()
        case .resume: tracker.resume()
        case .finish:
            // Never saves from here: show the Record tab and ask on the iPhone.
            selectedTab = .record
            finishRequestedFromWatch = true
        case .ignore: break
        }
    }
}