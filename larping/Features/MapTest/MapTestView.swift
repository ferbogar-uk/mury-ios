import CoreLocation
import SwiftData
import SwiftUI

/// Test screen (build 50): plays the same flyover camera path on Apple's map and on Mapbox, so Ricardo can
/// compare them on his phone. Preview only: no recording, no render, no sharing, and no trail reveal or marker.
/// Mapbox's terms restrict shared video, so nothing produced here may leave the phone. Mapbox is asked for map
/// tiles for the area shown, so this is the one place the app sends anything to a map server other than Apple.
struct MapTestView: View {
    private enum Provider: String, CaseIterable, Identifiable {
        case apple = "Apple", mapbox3D = "Mapbox 3D", mapboxSatellite = "Mapbox satellite"
        var id: String { rawValue }
    }

    @Query(sort: \CDActivity.startedAt, order: .reverse) private var activities: [CDActivity]
    @Environment(\.brandTheme) private var theme
    @State private var provider: Provider = .apple
    @State private var chosen: CDActivity?
    @State private var plan: FlyoverPlan?
    @State private var route: [CLLocationCoordinate2D] = []
    @State private var flyTime: TimeInterval = 0
    @State private var isPlaying = false

    private var candidates: [CDActivity] { activities.filter { $0.trackPoints.count > 1 }.prefix(10).map { $0 } }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Map", selection: $provider) {
                ForEach(Provider.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("maptest-provider")

            if let plan, plan.isUsable {
                mapArea(plan: plan)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                controls
            } else {
                Spacer()
                Text(candidates.isEmpty ? "Record or import an activity with a route to compare the maps."
                                        : "This route is too short for a flyover.")
                    .font(MuryTypography.font(.subheadline, size: 15))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .padding(16)
        .background(theme.canvas)
        .navigationTitle("Map test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if chosen == nil, let first = candidates.first { choose(first) } }
        .task(id: isPlaying) { await run() }
        .onDisappear { isPlaying = false }
    }

    @ViewBuilder private func mapArea(plan: FlyoverPlan) -> some View {
        let state = plan.state(at: flyTime)
        switch provider {
        case .apple:
            AppleFlyoverMap(route: route, state: state)
        case .mapbox3D, .mapboxSatellite:
            if MapboxConfig.isAvailable {
                MapboxFlyoverMap(style: provider == .mapbox3D ? .standard : .satellite, route: route, state: state)
                    .id(provider)
            } else {
                Text("This build has no Mapbox token, so only the Apple map works. TestFlight builds include it.")
                    .font(MuryTypography.font(.subheadline, size: 15))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if !isPlaying && flyTime >= (plan?.clipSeconds ?? 0) { flyTime = 0 }
                isPlaying.toggle()
            } label: {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .accessibilityIdentifier("maptest-play")
            Button { isPlaying = false; flyTime = 0 } label: {
                Image(systemName: "backward.end.fill").frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Back to the start")
            if candidates.count > 1 {
                Menu {
                    ForEach(candidates, id: \.persistentModelID) { item in
                        Button(item.eventName ?? item.sportType.label) { choose(item) }
                    }
                } label: {
                    Image(systemName: "list.bullet").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Choose activity")
            }
        }
    }

    private func choose(_ activity: CDActivity) {
        isPlaying = false
        flyTime = 0
        chosen = activity
        let raw = activity.trackPoints.map {
            ReplayPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps)
        }
        let smoothed = RouteSmoothing.smoothed(raw, halfWindowSeconds: 10)
        let timeline = ReplayTimeline(points: smoothed, startedAt: activity.startedAt, endedAt: activity.endedAt)
        plan = FlyoverPlan(timeline: timeline, clipSeconds: 30)
        route = smoothed.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func run() async {
        guard isPlaying, let plan else { return }
        let clock = ContinuousClock()
        let begin = clock.now
        let startOffset = flyTime
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            if Task.isCancelled { return }
            let parts = begin.duration(to: clock.now).components
            let elapsed = startOffset + Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            flyTime = min(elapsed, plan.clipSeconds)
            if elapsed >= plan.clipSeconds { isPlaying = false; return }
        }
    }
}
