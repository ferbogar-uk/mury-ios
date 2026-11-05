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
        .onAppear { WatchMirror.shared.onCommand = { handleWatchCommand($0) } }
        .task {
            if activitiesStore == nil {
                SeedData.seedIfNeeded(context: modelContext)
                let store = ActivitiesStore(modelContext: modelContext)
                activitiesStore = store
                store.refresh()
            }
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