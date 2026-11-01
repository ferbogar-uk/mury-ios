import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var activitiesStore: ActivitiesStore?

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
                .toolbarBackground(theme.navigation, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                ProgressView()
            }
        }
        .task {
            if activitiesStore == nil {
                SeedData.seedIfNeeded(context: modelContext)
                let store = ActivitiesStore(modelContext: modelContext)
                activitiesStore = store
                store.refresh()
            }
        }
    }
}