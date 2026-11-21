import SwiftData
import SwiftUI

struct ActivitiesListView: View {
    @Environment(\.brandTheme) private var theme
    @Query(sort: \CDActivity.startedAt, order: .reverse) private var activities: [CDActivity]
    @State private var showGPXImport = false
    @State private var showHealthImport = false

    @State private var sportFilter: SportType?

    private var shown: [CDActivity] {
        activities.filter { ActivityListRules.matches($0.statsEntry, sport: sportFilter) }
    }

    private var monthSections: [MonthGrouping.Section<CDActivity>] {
        MonthGrouping.sections(shown, date: \.startedAt, calendar: Calendar.current)
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
                "Record your first activity",
                systemImage: "figure.run",
                description: Text("Record from the Record tab, or bring workouts in from Apple Health or a GPX file with the import button.")
            )
        } else {
            let sports = ActivityListRules.sports(in: activities.map(\.statsEntry))
            let now = Date()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    if sports.count > 1 { filterChips(sports) }
                    ForEach(monthSections, id: \.month) { section in
                        Section {
                            ForEach(section.items) { activity in
                                NavigationLink(value: activity.id) {
                                    if activity.trackPoints.count > 1 {
                                        ActivityRouteCard(activity: activity)
                                    } else {
                                        CompactActivityCard(activity: activity)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityIdentifier("activity-row-" + activity.sportType.rawValue)
                                .padding(.horizontal, 16)
                            }
                        } header: {
                            monthHeader(section, now: now)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationDestination(for: UUID.self) { id in
                if let activity = activities.first(where: { $0.id == id }) {
                    ActivityDetailView(activity: activity)
                }
            }
            .onChange(of: sports) { _, available in
                if let chosen = sportFilter, !available.contains(chosen) { sportFilter = nil }
            }
        }
    }

    private func filterChips(_ sports: [SportType]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", symbol: nil, selected: sportFilter == nil, id: "activity-filter-all") { sportFilter = nil }
                ForEach(sports) { sport in
                    chip(sport.label, symbol: sport.symbolName, selected: sportFilter == sport,
                         id: "activity-filter-" + sport.rawValue) { sportFilter = sport }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
        .padding(.top, 8)
    }

    private func chip(_ label: String, symbol: String?, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(label)
            }
            .font(MuryTypography.font(.subheadline, size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? theme.onAccent : theme.ink)
            .background(selected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.surface), in: Capsule())
            .overlay(Capsule().strokeBorder(theme.border.opacity(selected ? 0 : 0.35), lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func monthHeader(_ section: MonthGrouping.Section<CDActivity>, now: Date) -> some View {
        let total = ActivityListRules.total(section.items.map(\.statsEntry))
        var parts = [ActivityListRules.countLabel(total.count)]
        if total.distanceMeters > 0 { parts.insert(Formatters.distance(meters: total.distanceMeters), at: 0) }
        if total.durationSeconds > 0 { parts.append(Formatters.duration(seconds: total.durationSeconds)) }
        return HStack(alignment: .firstTextBaseline) {
            Text(ActivityListRules.monthTitle(section.month, now: now, calendar: .current))
                .font(MuryTypography.font(.title3, size: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(parts.joined(separator: " · "))
                .font(MuryTypography.font(.caption, size: 12).monospacedDigit())
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.canvas)
    }
}

/// Activities without a route (gym, treadmill…): a sport tile and up to three numbers.
private struct CompactActivityCard: View {
    let activity: CDActivity
    @Environment(\.brandTheme) private var theme

    private var title: String {
        let name = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? activity.sportType.label : name
    }

    /// Distance and pace when there is a distance (treadmill), otherwise time, heart rate and calories.
    private var numbers: [String] {
        var items: [String] = []
        if let meters = activity.distanceMeters, meters > 0 {
            items.append(Formatters.distance(meters: Double(meters)))
            items.append(Formatters.duration(seconds: activity.durationSeconds))
            items.append(Formatters.paceOrSpeed(sportType: activity.sportType,
                                                averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
                                                averageSpeedMps: activity.averageSpeedMps))
        } else {
            items.append(Formatters.duration(seconds: activity.durationSeconds))
            if let bpm = activity.averageHeartRateBpm { items.append("\(bpm) bpm") }
            if let kcal = activity.calories { items.append("\(kcal) kcal") }
        }
        return items
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: activity.sportType.symbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 52)
                .background(theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .font(MuryTypography.font(.caption, size: 12))
                    .foregroundStyle(theme.muted)
                Text(title)
                    .font(MuryTypography.font(.headline, size: 16, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                HStack(spacing: 14) {
                    ForEach(numbers, id: \.self) { Text($0) }
                }
                .font(MuryTypography.font(.subheadline, size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: theme.ink.opacity(0.06), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
    }
}
