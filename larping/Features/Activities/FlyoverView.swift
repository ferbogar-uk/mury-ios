import AVKit
import MapKit
import ReplayKit
import SwiftUI

/// Strava-style route flyover: whole route from above, one turn tilting down onto the start,
/// then the camera chases the moving point while the trail grows. It can be recorded with the
/// system screen recorder (in-app capture only) and shared as a video.
struct FlyoverView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: Equatable {
        case idle, preloading, preparing, playing, recording, finishing, rendering, done
    }

    private enum ClipLength: Int, CaseIterable, Identifiable {
        case fifteen = 15, thirty = 30, sixty = 60
        var id: Int { rawValue }
    }

    private let timeline: ReplayTimeline
    private let symbol: String
    private let savedDistance: String

    @State private var clip: ClipLength = .thirty
    @State private var plan: FlyoverPlan
    @State private var camera: MapCameraPosition
    @State private var flyTime: TimeInterval = 0
    @State private var mode: Mode = .idle
    @State private var recorded: VideoShareFile?
    @State private var player: AVPlayer?
    @State private var message: String?
    @State private var afterPreload: Mode = .playing
    @State private var renderProgress: FlyoverRenderer.Progress?
    @State private var renderTask: Task<Void, Never>?
    @State private var renderSummary: String?
    @State private var renderStartedAt = Date()

    init(activity: CDActivity) {
        // Smoothed over ~10 s each way so the drawn line and the camera follow the general path, not the GPS wobble.
        let raw = activity.trackPoints.map {
            ReplayPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps)
        }
        let snapshot = ReplayTimeline(points: RouteSmoothing.smoothed(raw, halfWindowSeconds: 10),
                                      startedAt: activity.startedAt, endedAt: activity.endedAt)
        timeline = snapshot
        symbol = activity.sportType.symbolName
        savedDistance = Formatters.distance(meters: activity.distanceMeters.map(Double.init))
        let first = FlyoverPlan(timeline: snapshot, clipSeconds: Double(ClipLength.thirty.rawValue))
        _plan = State(initialValue: first)
        let opening = first.state(at: 0)
        _camera = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: opening.centerLatitude, longitude: opening.centerLongitude),
            distance: opening.distanceMeters, heading: 0, pitch: 0)))
    }

    private var isRunning: Bool {
        mode == .preloading || mode == .preparing || mode == .playing || mode == .recording || mode == .finishing
    }

    var body: some View {
        let state = plan.state(at: flyTime)
        let frame = timeline.sample(at: state.routeElapsedSeconds)
        ZStack {
            theme.canvas.ignoresSafeArea()
            if plan.isUsable {
                flyMap(state: state, frame: frame)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if mode == .recording || mode == .playing || mode == .preloading { abortRun("Flyover stopped.") }
                    }
                controlsOverlay(state: state, frame: frame)
            } else {
                ContentUnavailableView("Flyover unavailable", systemImage: "map",
                    description: Text("This activity needs at least two usable timed GPS points.")
                        .font(MuryTypography.font(.body, size: 17)))
                VStack {
                    HStack { closeButton; Spacer() }
                    Spacer()
                }
                .padding()
            }
        }
        .tint(theme.accent)
        .statusBarHidden(mode == .recording || mode == .finishing)
        .persistentSystemOverlays(mode == .recording || mode == .finishing ? .hidden : .automatic)
        .onChange(of: clip) { _, length in
            plan = FlyoverPlan(timeline: timeline, clipSeconds: Double(length.rawValue))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && isRunning && mode != .finishing {
                abortRun("Flyover stopped because MURY left the screen.")
            }
            if phase != .active && mode == .rendering {
                cancelRender("Render stopped because MURY left the screen. Map images can only be fetched while the app is open.")
            }
        }
        .onDisappear {
            if isRunning && mode != .finishing { abortRun(nil) }
            if mode == .rendering { cancelRender(nil) }
        }
        .task(id: mode) {
            if mode == .preloading {
                await preloadMap()
                return
            }
            guard mode == .playing || mode == .recording else { return }
            let clock = ContinuousClock()
            let begin = clock.now
            let length = plan.clipSeconds
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                if Task.isCancelled { return }
                let parts = begin.duration(to: clock.now).components
                let elapsed = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
                flyTime = min(elapsed, length)
                apply(plan.state(at: flyTime))
                if elapsed >= length {
                    Task { await finishRun() }
                    return
                }
            }
        }
    }

    // MARK: - Map

    private func flyMap(state: FlyoverPlan.State, frame: ReplayFrame) -> some View {
        Map(position: $camera, interactionModes: []) {
            ForEach(Array(timeline.segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.route.opacity(0.3), lineWidth: 4)
            }
            ForEach(Array(frame.revealedSegments.enumerated()), id: \.offset) { _, segment in
                // One plain red line, same width everywhere (no white casing, which made it look uneven).
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.route, lineWidth: 4)
            }
            if let first = timeline.segments.first?.first {
                Annotation("Start", coordinate: coordinate(first)) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                }
            }
            if state.phase != .overview, state.markerDrop < 1, let position = frame.position {
                Annotation("Position", coordinate: coordinate(position)) {
                    Image(systemName: symbol)
                        .font(.headline)
                        .foregroundStyle(theme.routeCasing)
                        .padding(8)
                        .background(theme.route, in: Circle())
                        .overlay(Circle().strokeBorder(theme.routeCasing, lineWidth: 2))
                        // Drops in from above and lands on the start point.
                        .offset(y: -state.markerDrop * 360)
                        .opacity(min(1, (1 - state.markerDrop) * 6))
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .accessibilityIdentifier("flyover-map")
    }

    // MARK: - Overlay

    @ViewBuilder
    private func controlsOverlay(state: FlyoverPlan.State, frame: ReplayFrame) -> some View {
        VStack(spacing: 12) {
            HStack {
                if mode == .idle || mode == .done { closeButton }
                Spacer()
            }
            Spacer()
            if isRunning && mode != .preparing && mode != .preloading {
                statsCard(state: state, frame: frame)
            }
            if mode == .preparing || mode == .preloading {
                Text(mode == .preloading ? "Preparing map…" : "Starting recording…")
                    .font(MuryTypography.font(.subheadline, size: 15))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
            }
            if mode == .rendering {
                renderCard
            }
            if mode == .idle || mode == .done {
                panel
            }
        }
        .padding()
    }

    private var renderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rendering in the app (experimental)")
                .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
            if let progress = renderProgress {
                if let preview = progress.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity)
                }
                ProgressView(value: Double(progress.frame), total: Double(max(progress.total, 1)))
                Text("Frame \(progress.frame) of \(progress.total) · \(String(format: "%.1f", progress.averageSecondsPerFrame)) s per frame · about \(Self.minutesText(progress.secondsRemaining)) left")
                    .font(MuryTypography.font(.caption, size: 12))
                    .monospacedDigit()
            } else {
                ProgressView()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Asking Apple Maps for the first images… \(Int(context.date.timeIntervalSince(renderStartedAt))) s. The first ones take longest.")
                        .font(MuryTypography.font(.caption, size: 12))
                        .monospacedDigit()
                }
            }
            Text("Keep MURY open and the screen on. Nothing is recorded from the screen.")
                .font(MuryTypography.font(.caption, size: 12))
                .opacity(0.75)
            Button("Cancel", role: .cancel) {
                cancelRender("Render cancelled.")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("flyover-render-cancel")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private static func minutesText(_ seconds: Double) -> String {
        let total = Int(seconds.isFinite ? max(0, seconds) : 0)
        return total >= 60 ? "\(total / 60) min \(total % 60) s" : "\(total) s"
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Close flyover")
        .accessibilityIdentifier("flyover-close")
    }

    private func statsCard(state: FlyoverPlan.State, frame: ReplayFrame) -> some View {
        HStack {
            stat("Total distance", savedDistance)
            Spacer()
            stat("Time", Formatters.duration(seconds: Int(min(state.routeElapsedSeconds, Double(Int.max / 2)))))
            Spacer()
            stat("Speed", Formatters.speed(metersPerSecond: frame.speedMps))
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(MuryTypography.font(.caption, size: 12)).opacity(0.75)
            Text(value).font(MuryTypography.font(.headline, size: 20, weight: .semibold)).monospacedDigit()
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode == .done, let file = recorded {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                ShareLink(item: file.url, preview: SharePreview("My MURY route flyover")) {
                    Label("Share video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("flyover-share")
            }
            Picker("Length", selection: $clip) {
                ForEach(ClipLength.allCases) { length in Text("\(length.rawValue) s").tag(length) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("flyover-length")
            HStack(spacing: 12) {
                Button {
                    startPreview()
                } label: {
                    Label("Preview", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("flyover-preview")
                Button {
                    startRecording()
                } label: {
                    Label(mode == .done ? "Record again" : "Record video", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("flyover-record")
            }
            Button {
                startRender()
            } label: {
                Label("Render in app (experimental)", systemImage: "film").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("flyover-render")
            if let renderSummary, mode == .done {
                Text(renderSummary)
                    .font(MuryTypography.font(.caption, size: 12))
                    .foregroundStyle(.secondary)
            }
            if let message {
                Text(message)
                    .font(MuryTypography.font(.caption, size: 12))
                    .foregroundStyle(.red)
            }
            Text("Render in app builds the video from map images, with no screen recording and no permission prompt. It is slow (minutes) and still being tested: the 3D look, the route alignment and the speed are not confirmed on a phone yet. "
                 + "Recording captures this screen while the flyover plays. Keep MURY open and tap the screen to stop. Satellite and 3D coverage depend on Apple Maps.")
                .font(MuryTypography.font(.caption, size: 12))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Running

    private func startPreview() {
        guard plan.isUsable else { return }
        beginPreload(then: .playing)
    }

    private func beginPreload(then next: Mode) {
        message = nil
        afterPreload = next
        flyTime = 0
        apply(plan.state(at: 0))
        mode = .preloading
    }

    /// Asks MapKit for imagery along the route without moving the visible map, then waits (at most ~6 s) so tiles
    /// are more likely to be cached when the flyover passes. MapKit has no public offline or cache-control API and
    /// does not say when tiles are ready, so this is best effort and the cache cannot be cleared by the app.
    private func preloadMap() async {
        let counter = SnapshotCounter()
        let stops = 8
        var requested = 0
        for index in 0...stops {
            let progress = Double(index) / Double(stops)
            guard let center = FlyoverPlan.position(timeline: timeline, progress: progress) else { continue }
            let latitude = center.latitude
            let longitude = center.longitude
            let heading = FlyoverPlan.smoothedHeading(timeline: timeline, progress: progress)
            let distance = FlyoverPlan.followDistanceMeters
            requested += 1
            Task.detached {
                let options = MKMapSnapshotter.Options()
                options.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                             fromDistance: distance,
                                             pitch: 60, heading: heading)
                options.size = CGSize(width: 390, height: 844)
                options.scale = 1
                options.mapType = .hybridFlyover
                _ = try? await MKMapSnapshotter(options: options).start()
                counter.finishOne()
            }
        }
        var waited = 0.0
        while counter.finished < requested, waited < 6, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 0.1
        }
        if Task.isCancelled { return }
        flyTime = 0
        apply(plan.state(at: 0))
        try? await Task.sleep(for: .milliseconds(400))
        guard mode == .preloading, !Task.isCancelled else { return }
        if afterPreload == .recording {
            startRecordingNow()
        } else {
            mode = .playing
        }
    }

    private func startRender() {
        guard plan.isUsable else { return }
        message = nil
        recorded = nil
        player = nil
        renderSummary = nil
        renderProgress = nil
        renderStartedAt = Date()
        mode = .rendering
        UIApplication.shared.isIdleTimerDisabled = true
        let renderPlan = plan
        renderTask = Task {
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            do {
                let output = try await FlyoverRenderer.render(
                    plan: renderPlan, timeline: timeline, routeColor: UIColor(theme.route), symbolName: symbol,
                    savedDistance: savedDistance, reduceMotion: reduceMotion
                ) { progress in
                    renderProgress = progress
                }
                defer { try? FileManager.default.removeItem(at: output.url) }
                let file = try VideoShareFile(source: output.url)
                recorded = file
                player = AVPlayer(url: file.url)
                let each = output.totalSeconds / Double(max(output.frames, 1))
                renderSummary = "Rendered in the app: \(output.frames) frames in \(Self.minutesText(output.totalSeconds)) (\(String(format: "%.1f", each)) s per frame)."
                resetToStart(newMode: .done)
            } catch is CancellationError {
                if mode == .rendering { resetToStart() }
            } catch {
                message = error.localizedDescription
                resetToStart()
            }
        }
    }

    private func cancelRender(_ note: String?) {
        renderTask?.cancel()
        renderTask = nil
        if let note { message = note }
        if mode == .rendering { resetToStart() }
    }

    private func startRecording() {
        guard plan.isUsable else { return }
        guard RPScreenRecorder.shared().isAvailable else {
            message = "Screen recording is not available right now. You can still preview the flyover."
            return
        }
        recorded = nil
        player = nil
        beginPreload(then: .recording)
    }

    private func startRecordingNow() {
        let recorder = RPScreenRecorder.shared()
        message = nil
        flyTime = 0
        apply(plan.state(at: 0))
        mode = .preparing
        Task {
            do {
                try await recorder.startRecording()
                // Let the system permission banner leave the screen before the camera moves.
                try? await Task.sleep(for: .milliseconds(700))
                if mode == .preparing {
                    mode = .recording
                } else if recorder.isRecording {
                    discardRecording()
                }
            } catch {
                message = "Could not start recording: \(error.localizedDescription)"
                mode = .idle
            }
        }
    }

    private func finishRun() async {
        guard mode == .recording else {
            if mode == .playing { resetToStart() }
            return
        }
        mode = .finishing
        // Hold the last frame a moment so the clip does not cut mid-move.
        try? await Task.sleep(for: .milliseconds(600))
        let url = temporaryVideoURL()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try await RPScreenRecorder.shared().stopRecording(withOutput: url)
            let file = try VideoShareFile(source: url)
            recorded = file
            player = AVPlayer(url: file.url)
            resetToStart(newMode: .done)
        } catch {
            message = "Could not save the video: \(error.localizedDescription)"
            resetToStart()
        }
    }

    private func abortRun(_ note: String?) {
        let wasRecording = RPScreenRecorder.shared().isRecording
        message = note
        resetToStart()
        if wasRecording { discardRecording() }
    }

    private func discardRecording() {
        let url = temporaryVideoURL()
        Task {
            try? await RPScreenRecorder.shared().stopRecording(withOutput: url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func resetToStart(newMode: Mode = .idle) {
        flyTime = 0
        apply(plan.state(at: 0))
        mode = newMode
    }

    private func temporaryVideoURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MURY-flyover-" + UUID().uuidString + ".mp4")
    }

    // MARK: - Camera

    private func apply(_ state: FlyoverPlan.State) {
        camera = .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            distance: state.distanceMeters,
            // Reduce Motion: no spinning or tilting, just a flat follow.
            heading: reduceMotion ? 0 : state.headingDegrees,
            pitch: reduceMotion ? 0 : state.pitchDegrees))
    }

    private func coordinate(_ point: ReplayCoordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }
}

/// Counts finished background snapshot requests (read from the main actor, written from background tasks).
nonisolated private final class SnapshotCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var finished: Int { lock.lock(); defer { lock.unlock() }; return count }
    func finishOne() { lock.lock(); count += 1; lock.unlock() }
}
