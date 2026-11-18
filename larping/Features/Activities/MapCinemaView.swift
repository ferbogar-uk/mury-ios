import AVKit
import CoreLocation
import MapTilerSDK
import ReplayKit
import SwiftUI

/// TEST screen (build 24): the same flyover as `FlyoverView`, but on a live MapTiler map with a much lower camera
/// (like Strava), recorded with the system screen recorder, then watched on a separate "cinema" screen that
/// only plays the finished video. There is one map and it never takes per-frame pictures, so it does not hit the
/// memory growth that stopped the in-app render.
///
/// Unproven on a real device when this was written. Needs the MapTiler key (see `MapTilerConfig`) and internet.
struct MapCinemaView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private enum Mode: Equatable {
        case loading, ready, preparing, playing, recording, finishing, cinema
    }

    /// Camera tilt while following. Apple Maps stops near 65 degrees; MapTiler allows up to 85.
    static let cinemaPitchDegrees = 78.0
    static let maxPitchDegrees = 85.0

    private let timeline: ReplayTimeline
    private let routeGeoJSON: String

    @State private var plan: FlyoverPlan
    @State private var mapView: MTMapView?
    @State private var routeSource: MTGeoJSONSource?
    @State private var trailSource: MTGeoJSONSource?
    @State private var mode: Mode = .loading
    @State private var flyTime: TimeInterval = 0
    @State private var message: String?
    @State private var recorded: VideoShareFile?
    @State private var player: AVPlayer?
    @State private var lastTrailUpdate: TimeInterval = -1

    init(activity: CDActivity) {
        let raw = activity.trackPoints.map {
            ReplayPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps)
        }
        let snapshot = ReplayTimeline(points: RouteSmoothing.smoothed(raw, halfWindowSeconds: 10),
                                      startedAt: activity.startedAt, endedAt: activity.endedAt)
        timeline = snapshot
        routeGeoJSON = MapCinemaMath.geoJSON(segments: snapshot.segments)
        _plan = State(initialValue: FlyoverPlan(timeline: snapshot, clipSeconds: 30))
    }

    private var isRunning: Bool { mode == .preparing || mode == .playing || mode == .recording || mode == .finishing }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !plan.isUsable {
                ContentUnavailableView("Flyover unavailable", systemImage: "map",
                    description: Text("This activity needs at least two usable timed GPS points."))
                    .foregroundStyle(.white)
            } else {
                // The map stays in the hierarchy under the cinema screen: removing it would tear down its web view.
                mapLayer
                if mode == .cinema {
                    Color.black.ignoresSafeArea()
                    cinema
                } else {
                    overlay
                }
            }
        }
        .tint(theme.accent)
        .statusBarHidden(mode == .recording || mode == .finishing)
        .persistentSystemOverlays(mode == .recording || mode == .finishing ? .hidden : .automatic)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && isRunning && mode != .finishing { abortRun("Stopped because MURY left the screen.") }
        }
        .onDisappear {
            if isRunning && mode != .finishing { abortRun(nil) }
            mapView?.destroy()
        }
        .task { await prepareMap() }
        .task(id: mode) { await runClock() }
    }

    // MARK: - Map

    @ViewBuilder private var mapLayer: some View {
        if let mapView, let routeSource, let trailSource {
            MTMapViewContainer(map: mapView) {
                routeSource
                Self.line("route-faint", source: routeSource, color: UIColor.white.withAlphaComponent(0.55), width: 3)
                trailSource
                Self.line("trail", source: trailSource, color: UIColor(theme.route), width: 6)
            }
            .referenceStyle(.satellite)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { if mode == .recording || mode == .playing { abortRun("Stopped.") } }
        } else {
            ProgressView().tint(.white)
        }
    }

    private static func line(_ id: String, source: MTGeoJSONSource, color: UIColor, width: Double) -> MTLineLayer {
        let layer = MTLineLayer(identifier: id, sourceIdentifier: source.identifier)
        layer.color = color
        layer.width = width
        layer.cap = .round
        layer.join = .round
        return layer
    }

    private func prepareMap() async {
        guard plan.isUsable, mapView == nil else { return }
        guard let key = MapTilerConfig.apiKey else {
            message = "This build has no MapTiler key, so the map cannot load."
            mode = .ready
            return
        }
        await MTConfig.shared.setAPIKey(key)
        let opening = plan.state(at: 0)
        let options = MTMapOptions(
            center: CLLocationCoordinate2D(latitude: opening.centerLatitude, longitude: opening.centerLongitude),
            zoom: MapCinemaMath.zoom(forDistance: opening.distanceMeters, latitude: opening.centerLatitude),
            bearing: opening.headingDegrees, pitch: 0, maxPitch: Self.maxPitchDegrees,
            terrainIsEnabled: true, terrainExaggeration: 1.0)
        routeSource = MTGeoJSONSource(identifier: "route", jsonString: routeGeoJSON)
        trailSource = MTGeoJSONSource(identifier: "trail", jsonString: MapCinemaMath.geoJSON(segments: []))
        mapView = MTMapView(options: options)
        // The SDK gives no public "tiles are ready" signal that the container leaves free, so wait a fixed moment.
        try? await Task.sleep(for: .seconds(4))
        if mode == .loading { mode = .ready }
    }

    // MARK: - Overlay

    private var overlay: some View {
        VStack(spacing: 12) {
            HStack {
                if mode == .ready || mode == .loading {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(12)
                            .background(.black.opacity(0.55), in: Circle()).foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
            Spacer()
            if mode == .loading {
                pill("Loading MapTiler map…")
            } else if mode == .preparing {
                pill("Starting recording…")
            } else if mode == .ready {
                panel
            }
        }
        .padding()
    }

    private func pill(_ text: String) -> some View {
        Text(text).font(MuryTypography.font(.subheadline, size: 15))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map cinema (test)").font(MuryTypography.font(.headline, size: 17, weight: .semibold))
            if let recorded {
                Button { showCinema(recorded) } label: {
                    Label("Open cinema", systemImage: "play.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 12) {
                Button { start(recording: false) } label: {
                    Label("Preview", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cinema-preview")
                Button { start(recording: true) } label: {
                    Label("Record", systemImage: "record.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cinema-record")
            }
            .disabled(mapView == nil)
            if let message {
                Text(message).font(MuryTypography.font(.caption, size: 12)).foregroundStyle(.red)
            }
            Text("Satellite map and 3D terrain from MapTiler, loaded over the internet for this screen only. Keep MURY open and tap the screen to stop.")
                .font(MuryTypography.font(.caption, size: 12)).foregroundStyle(.secondary)
        }
        .padding()
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Cinema

    private var cinema: some View {
        VStack(spacing: 16) {
            HStack {
                Button { stopPlayer(); mode = .ready } label: {
                    Label("Back", systemImage: "chevron.left").foregroundStyle(.white)
                }
                Spacer()
                if let recorded {
                    ShareLink(item: recorded.url) { Label("Share", systemImage: "square.and.arrow.up") }
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
            Spacer(minLength: 0)
        }
        .padding(.top)
    }

    private func showCinema(_ file: VideoShareFile) {
        let item = AVPlayer(url: file.url)
        player = item
        mode = .cinema
        item.play()
    }

    private func stopPlayer() {
        player?.pause()
        player = nil
    }

    // MARK: - Running

    private func start(recording: Bool) {
        guard plan.isUsable, mapView != nil else { return }
        message = nil
        flyTime = 0
        lastTrailUpdate = -1
        if recording {
            guard RPScreenRecorder.shared().isAvailable else {
                message = "Screen recording is not available right now."
                return
            }
            recorded = nil
            stopPlayer()
            mode = .preparing
            Task {
                do {
                    try await RPScreenRecorder.shared().startRecording()
                    try? await Task.sleep(for: .milliseconds(700))
                    if mode == .preparing { mode = .recording } else if RPScreenRecorder.shared().isRecording { discardRecording() }
                } catch {
                    message = "Could not start recording: \(error.localizedDescription)"
                    mode = .ready
                }
            }
        } else {
            mode = .playing
        }
    }

    /// Drives the camera from a clock while playing or recording.
    private func runClock() async {
        guard mode == .playing || mode == .recording, let mapView else { return }
        await apply(plan.state(at: 0), on: mapView, force: true)
        let clock = ContinuousClock()
        let begin = clock.now
        let length = plan.clipSeconds
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            if Task.isCancelled { return }
            let parts = begin.duration(to: clock.now).components
            let elapsed = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            flyTime = min(elapsed, length)
            await apply(plan.state(at: flyTime), on: mapView, force: false)
            if elapsed >= length {
                await finishRun()
                return
            }
        }
    }

    private func apply(_ state: FlyoverPlan.State, on mapView: MTMapView, force: Bool) async {
        let center = CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude)
        let pitch = min(Self.maxPitchDegrees, state.pitchDegrees * Self.cinemaPitchDegrees / FlyoverPlan.followPitchDegrees)
        await mapView.jumpTo(center, options: MTCameraOptions(
            zoom: MapCinemaMath.zoom(forDistance: state.distanceMeters, latitude: state.centerLatitude),
            bearing: state.headingDegrees, pitch: pitch))
        // The growing trail is a file the map reads; refreshing it a few times a second is enough.
        if force || flyTime - lastTrailUpdate >= 0.25, let trailSource {
            lastTrailUpdate = flyTime
            let frame = timeline.sample(at: state.routeElapsedSeconds)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("mury-cinema-trail.geojson")
            if (try? MapCinemaMath.geoJSON(segments: frame.revealedSegments).write(to: url, atomically: true, encoding: .utf8)) != nil {
                await trailSource.setData(data: url, in: mapView)
            }
        }
    }

    private func finishRun() async {
        guard mode == .recording else {
            if mode == .playing { mode = .ready }
            return
        }
        mode = .finishing
        try? await Task.sleep(for: .milliseconds(600))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MURY-cinema-" + UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        guard RPScreenRecorder.shared().isRecording else {
            message = "The system stopped the recording before the flyover ended. Tap Record to try again."
            mode = .ready
            return
        }
        do {
            try await RPScreenRecorder.shared().stopRecording(withOutput: url)
            let file = try VideoShareFile(source: url)
            recorded = file
            showCinema(file)
        } catch {
            message = "Could not save the video: \(error.localizedDescription)"
            mode = .ready
        }
    }

    private func abortRun(_ note: String?) {
        let wasRecording = RPScreenRecorder.shared().isRecording
        message = note
        mode = .ready
        if wasRecording { discardRecording() }
    }

    private func discardRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MURY-cinema-" + UUID().uuidString + ".mp4")
        Task {
            try? await RPScreenRecorder.shared().stopRecording(withOutput: url)
            try? FileManager.default.removeItem(at: url)
        }
    }

}
