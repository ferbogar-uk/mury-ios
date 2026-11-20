import Charts
import MapKit
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.brandTheme) private var theme

    let activity: CDActivity

    @Environment(ActivitiesStore.self) private var store
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showReplay = false
    @State private var showFlyover = false
    @State private var showMapCinema = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var actionErrorMessage: String?
    @State fileprivate var splits: [ActivitySplit] = []
    @State fileprivate var elevation: [ElevationSample] = []
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        let trimmed = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? activity.sportType.label : trimmed
    }

    private var coordinates: [CLLocationCoordinate2D] {
        store.coordinates(for: activity)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if coordinates.count > 1 {
                    RouteMap(coordinates: coordinates, sportType: activity.sportType)
                        .frame(height: 300)
                        .accessibilityLabel("Route map")
                }

                header
                    .padding(.horizontal, 20)
                    .padding(.top, coordinates.count > 1 ? 0 : 8)

                if coordinates.count > 1 {
                    routeActions.padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if !splits.isEmpty { splitsCard }
                    if elevation.count > 1 { elevationCard }
                    HeartRateSection(activity: activity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .task(id: activity.id) { analyse() }
        .background(theme.canvas)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.navigation, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("activity-share")
                    Button {
                        showMapCinema = true
                    } label: {
                        Label("Map cinema (test)", systemImage: "film")
                    }
                    .accessibilityIdentifier("activity-map-cinema")
                    Button {
                        renameText = title
                        showRename = true
                    } label: {
                        Label("Rename event", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete activity", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("activity-actions")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivityView(activity: activity, coordinates: coordinates)
        }
        .sheet(isPresented: $showReplay) {
            NavigationStack {
                ActivityReplayView(activity: activity)
            }
        }
        .fullScreenCover(isPresented: $showFlyover) {
            FlyoverView(activity: activity)
        }
        .fullScreenCover(isPresented: $showMapCinema) {
            MapCinemaView(activity: activity)
        }
        .alert("Rename event", isPresented: $showRename) {
            TextField("Event name", text: $renameText)
            Button("Save") {
                do {
                    try store.rename(activity, to: renameText)
                } catch {
                    actionErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \"\(title)\"?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do {
                    try store.delete(activity)
                    dismiss()
                } catch {
                    actionErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert("Couldn't save changes", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }
}

extension ActivityDetailView {
    // MARK: header

    fileprivate var sourceLabel: String? {
        switch activity.source {
        case "healthkit_import": "Apple Health"
        case WatchImport.source: "Apple Watch"
        case "mobile": "Recorded on iPhone"
        case "gpx_import": "GPX file"
        default: nil
        }
    }

    fileprivate var metaLine: String {
        [activity.sportType.label, Formatters.displayDate(date: activity.startedAt), sourceLabel]
            .compactMap { $0 }.joined(separator: " · ")
    }

    fileprivate var metrics: [(String, String)] {
        var items: [(String, String)] = [("Time", Formatters.duration(seconds: activity.durationSeconds))]
        items.append((activity.sportType.usesPaceMetric ? "Avg pace" : "Avg speed",
                      Formatters.paceOrSpeed(sportType: activity.sportType,
                                             averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
                                             averageSpeedMps: activity.averageSpeedMps)))
        if let gain = activity.elevationGainMeters, gain > 0 {
            items.append(("Elevation", Formatters.elevation(meters: Double(gain))))
        }
        if let maxSpeed = activity.maxSpeedMps {
            items.append(activity.sportType.usesPaceMetric
                ? ("Best pace", Formatters.paceFromSpeed(metersPerSecond: maxSpeed))
                : ("Top speed", Formatters.speed(metersPerSecond: maxSpeed)))
        }
        if let avg = activity.averageHeartRateBpm { items.append(("Avg HR", "\(avg) bpm")) }
        if let max = activity.maxHeartRateBpm { items.append(("Max HR", "\(max) bpm")) }
        if let calories = activity.calories {
            items.append((activity.caloriesMeasured ? "Calories" : "Calories (est.)", "\(calories)"))
        }
        return items
    }

    fileprivate var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: activity.sportType.symbolName)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text(metaLine)
                    .foregroundStyle(theme.muted)
            }
            .font(MuryTypography.font(.caption, size: 13))

            Text(title)
                .font(MuryTypography.font(.title, size: 26, weight: .bold))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)

            if let meters = activity.distanceMeters, meters > 0 {
                Text(Formatters.distance(meters: Double(meters)))
                    .font(MuryTypography.font(.largeTitle, size: 44, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .padding(.top, 6)
                    .accessibilityLabel("Distance \(Formatters.distance(meters: Double(meters)))")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
                      alignment: .leading, spacing: 14) {
                ForEach(metrics, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(MuryTypography.font(.caption, size: 12))
                            .foregroundStyle(theme.muted)
                        Text(item.1)
                            .font(MuryTypography.font(.headline, size: 17, weight: .bold).monospacedDigit())
                            .foregroundStyle(theme.ink)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(theme.border.opacity(0.25)).frame(height: 0.5) }
        }
    }

    fileprivate var routeActions: some View {
        HStack(spacing: 10) {
            Button { showReplay = true } label: {
                Label("Replay", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent, in: Capsule())
            }
            .accessibilityIdentifier("activity-replay")
            Button { showFlyover = true } label: {
                Label("Flyover", systemImage: "video")
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(theme.ink)
                    .background(theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
            }
            .accessibilityIdentifier("activity-flyover")
        }
        .font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
        .buttonStyle(PressableStyle())
    }

    // MARK: splits

    fileprivate var splitsCard: some View {
        let quickest = splits.map(\.secondsPerKm).filter { $0 > 0 }.min() ?? 1
        let fastest = ActivityAnalysis.fastestSplitIndex(splits)
        let pace = activity.sportType.usesPaceMetric
        return DetailCard(title: "Splits", trailing: pace ? "Pace per km" : "Speed per km") {
            VStack(spacing: 10) {
                ForEach(splits) { split in
                    let isFastest = split.index == fastest
                    HStack(spacing: 10) {
                        Text(split.isPartial
                             ? String(format: "%.1f", split.distanceMeters / 1000)
                             : "\(split.index)")
                            .font(MuryTypography.font(.caption, size: 12).monospacedDigit())
                            .foregroundStyle(theme.muted)
                            .frame(width: 28, alignment: .leading)
                        GeometryReader { geo in
                            Capsule()
                                .fill(isFastest ? theme.accent : theme.ink)
                                .frame(width: max(8, geo.size.width * quickest / max(split.secondsPerKm, 1)))
                        }
                        .frame(height: 8)
                        Text(splitValue(split, pace: pace))
                            .font(MuryTypography.font(.subheadline, size: 14,
                                                      weight: isFastest ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(theme.ink)
                            .frame(width: 64, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(split.isPartial
                        ? "Last \(String(format: "%.1f", split.distanceMeters / 1000)) kilometres"
                        : "Kilometre \(split.index)")
                    .accessibilityValue(splitValue(split, pace: pace) + (isFastest ? ", fastest" : ""))
                }
            }
        }
        .accessibilityIdentifier("activity-splits")
    }

    fileprivate func splitValue(_ split: ActivitySplit, pace: Bool) -> String {
        pace
            ? Formatters.pace(secondsPerKm: Int(split.secondsPerKm.rounded()))
            : Formatters.speed(metersPerSecond: split.seconds > 0 ? split.distanceMeters / split.seconds : nil)
    }

    // MARK: elevation

    fileprivate var elevationCard: some View {
        let low = elevation.map(\.altitudeMeters).min() ?? 0
        let high = elevation.map(\.altitudeMeters).max() ?? 0
        let total = elevation.last?.distanceMeters ?? 0
        let floor = low - max(5, (high - low) * 0.15)
        return DetailCard(title: "Elevation", trailing: "Highest \(Formatters.elevation(meters: high))") {
            VStack(alignment: .leading, spacing: 6) {
                Chart(elevation.indices, id: \.self) { index in
                    AreaMark(x: .value("km", elevation[index].distanceMeters / 1000),
                             yStart: .value("Floor", floor),
                             yEnd: .value("m", elevation[index].altitudeMeters))
                        .foregroundStyle(theme.ink.opacity(0.12))
                    LineMark(x: .value("km", elevation[index].distanceMeters / 1000),
                             y: .value("m", elevation[index].altitudeMeters))
                        .foregroundStyle(theme.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
                .chartYScale(domain: floor...(high + max(2, (high - low) * 0.1)))
                .chartXScale(domain: 0...max(total / 1000, 0.01))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                }
                .frame(height: 110)
                HStack {
                    Text("0 km")
                    Spacer()
                    Text(Formatters.distance(meters: total))
                }
                .font(MuryTypography.font(.caption, size: 12).monospacedDigit())
                .foregroundStyle(theme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Elevation profile")
            .accessibilityValue("From \(Formatters.elevation(meters: low)) to \(Formatters.elevation(meters: high))")
        }
        .accessibilityIdentifier("activity-elevation")
    }

    fileprivate func analyse() {
        let points = activity.trackPoints.map {
            AnalysisPoint(timestamp: $0.timestamp, latitude: $0.latitude,
                          longitude: $0.longitude, altitudeMeters: $0.altitudeMeters)
        }
        splits = ActivityAnalysis.splits(points)
        let profile = ActivityAnalysis.elevationProfile(points)
        let altitudes = profile.map(\.altitudeMeters)
        // A flat line (indoor or no barometer) says nothing, so it is not drawn.
        elevation = (altitudes.max() ?? 0) - (altitudes.min() ?? 0) >= 1 ? profile : []
    }
}

/// White rounded card with a title row, shared by the detail sections.
private struct DetailCard<Content: View>: View {
    @Environment(\.brandTheme) private var theme
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(MuryTypography.font(.headline, size: 17, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(MuryTypography.font(.caption, size: 12))
                        .foregroundStyle(theme.muted)
                }
            }
            content
        }
        .foregroundStyle(theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RouteMap: View {
    @Environment(\.brandTheme) private var theme

    let coordinates: [CLLocationCoordinate2D]
    let sportType: SportType

    private static let drawDuration: TimeInterval = 5.5

    @State private var startDate = Date()
    @State private var isDrawComplete = false

    private var region: MKCoordinateRegion {
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0, maxLng = lngs.max() ?? 0
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        // MapPolyline overlay reconciliation is too slow to keep up with a 60fps
        // TimelineView tick, so the line stayed visually static and only caught up
        // in one jump once ticking stopped. Throttling to ~12fps gives MapKit time
        // to actually apply each polyline update, keeping the line in step with
        // the marker instead of popping in at the end.
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: isDrawComplete)) { timeline in
            let progress = min(timeline.date.timeIntervalSince(startDate) / Self.drawDuration, 1)
            let revealedCount = max(2, Int(Double(coordinates.count) * progress))

            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: Array(coordinates.prefix(revealedCount)))
                    .stroke(theme.routeCasing, lineWidth: 8)
                MapPolyline(coordinates: Array(coordinates.prefix(revealedCount)))
                    .stroke(theme.route, lineWidth: 4)

                // The "person" marker: a sport-specific icon riding the tip of
                // the route while it draws, bouncing gently — it comes to rest
                // at the finish when the draw completes.
                Annotation("", coordinate: coordinates[revealedCount - 1]) {
                    Image(systemName: sportType.symbolName)
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.routeCasing)
                        .padding(7)
                        .background(theme.route, in: Circle())
                        .overlay(Circle().strokeBorder(theme.routeCasing, lineWidth: 2))
                        .symbolEffect(.bounce, options: .repeating, isActive: !isDrawComplete)
                }
            }
            .mapStyle(.standard)
            .allowsHitTesting(false)
            .animation(nil, value: revealedCount)
        }
        .task {
            startDate = Date()
            isDrawComplete = false
            try? await Task.sleep(for: .seconds(Self.drawDuration))
            isDrawComplete = true
        }
    }
}
