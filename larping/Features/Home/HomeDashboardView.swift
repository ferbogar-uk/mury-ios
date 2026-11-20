import SwiftUI

/// Home: the week in one big number with a day-by-day strip, one-tap recording by sport, and your
/// latest activities as map cards. Uses only data MURY holds today.
struct HomeDashboardView: View {
    @Environment(ActivitiesStore.self) private var store
    @Environment(\.brandTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var shownDistance: Double = 0
    let onRecord: (SportType) -> Void

    var body: some View {
        let summary = HomeSummary(activities: store.activities, now: now, calendar: .current)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weekBlock(summary)
                    recordStrip
                    recentBlock(summary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(theme.canvas)
            .toolbarBackground(theme.navigation, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("LogoHorizontal")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .accessibilityLabel("MURY")
                        .accessibilityIdentifier("home-brand-logo")
                }
            }
            .onAppear {
                now = Date()
                animateDistance(to: summary.weeklyDistanceMeters)
            }
            .onChange(of: summary.weeklyDistanceMeters) { _, value in animateDistance(to: value) }
            .refreshable { refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            now = Date()
        }
    }

    // MARK: Week

    private func weekBlock(_ summary: HomeSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 days")
                .font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
                .foregroundStyle(theme.muted)
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(Self.kilometres(shownDistance))
                        .font(MuryTypography.font(.largeTitle, size: 52, weight: .bold))
                        .tracking(-1.2)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: shownDistance))
                    Text("km")
                        .font(MuryTypography.font(.title3, size: 20, weight: .semibold))
                        .foregroundStyle(theme.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Distance, \(Formatters.distance(meters: summary.weeklyDistanceMeters))")
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.weeklyCount == 1 ? "1 activity" : "\(summary.weeklyCount) activities")
                    Text(Formatters.duration(seconds: summary.weeklyDurationSeconds))
                        .monospacedDigit()
                }
                .font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
                .foregroundStyle(theme.muted)
            }
            WeekStrip(days: summary.dailyDistance)
        }
        .padding(18)
        .background(cardBackground)
    }

    // MARK: Record

    private var recordStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record")
                .font(MuryTypography.font(.title3, size: 20, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SportType.recordable) { sport in
                        Button { onRecord(sport) } label: {
                            Label(sport.label, systemImage: sport.symbolName)
                                .font(MuryTypography.font(.body, size: 15, weight: .semibold))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 46)
                                .foregroundStyle(sport == .run ? theme.onAccent : theme.ink)
                                .background(sport == .run ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.surface), in: Capsule())
                                .shadow(color: theme.ink.opacity(sport == .run ? 0 : 0.06), radius: 2, y: 1)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Record \(sport.label)")
                        .accessibilityIdentifier("home-record-" + sport.rawValue)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Recent

    @ViewBuilder private func recentBlock(_ summary: HomeSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activities")
                .font(MuryTypography.font(.title3, size: 20, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            if store.isLoading {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.surface)
                        .frame(height: 230)
                        .redacted(reason: .placeholder)
                }
                .accessibilityLabel("Loading activities")
            } else if let error = store.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load activities", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { refresh() }
                        .accessibilityIdentifier("home-retry")
                }
                .background(cardBackground)
            } else if summary.recentActivities.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("No personal activities yet")
                        .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
                    Text("Record an activity, or connect Apple Health in Profile, and it shows up here.")
                        .font(MuryTypography.font(.subheadline, size: 15))
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
                .background(cardBackground)
            } else {
                ForEach(summary.recentActivities) { activity in
                    NavigationLink {
                        ActivityDetailView(activity: activity)
                    } label: {
                        ActivityRouteCard(activity: activity)
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(theme.ink)
                }
            }
        }
    }

    // MARK: Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.surface)
            .shadow(color: theme.ink.opacity(0.05), radius: 1, y: 1)
            .shadow(color: theme.ink.opacity(0.06), radius: 12, y: 6)
    }

    private func animateDistance(to meters: Double) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.9)) { shownDistance = meters }
    }

    private static func kilometres(_ meters: Double) -> String {
        (meters / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    private func refresh() {
        now = Date()
        store.refresh()
    }
}

/// Seven bars, oldest to today; days with distance use the brand red, today's label is emphasised.
private struct WeekStrip: View {
    let days: [DayTotal]
    @Environment(\.brandTheme) private var theme

    var body: some View {
        let maximum = max(days.map(\.distanceMeters).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                let isToday = Calendar.current.isDateInToday(day.day)
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(day.distanceMeters > 0 ? theme.accent : theme.border.opacity(0.22))
                                .frame(height: max(6, geo.size.height * day.distanceMeters / maximum))
                        }
                    }
                    .frame(height: 56)
                    Text(day.day, format: .dateTime.weekday(.narrow))
                        .font(MuryTypography.font(.caption2, size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? theme.ink : theme.muted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.day.formatted(.dateTime.weekday(.wide))), \(Formatters.distance(meters: day.distanceMeters))")
            }
        }
    }
}
