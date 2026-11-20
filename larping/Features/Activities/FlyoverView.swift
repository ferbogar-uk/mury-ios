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
    private let overlayInfo: VideoOverlayInfo

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
    /// The newest picture the renderer sent; kept here because only some frames carry one.
    @State private var renderPreview: UIImage?
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
        overlayInfo = VideoOverlayInfo.make(activity: activity,
                                            athleteName: UserDefaults.standard.string(forKey: "displayName") ?? "MURY User")
        let first = FlyoverPlan(timeline: snapshot, clipSeconds: Double(ClipLength.thirty.rawValue))
        _plan = State(initialValue: first)
        let opening = first.state(at: 0)
        _camera = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: opening.centerLatitude, longitude: opening.centerLongitude),
            distance: opening.distanceMeters, heading: 0, pitch: 0)))
    }

    /// Render in app uses the length chosen in the picker (15 / 30 / 60 s) again, to find what the device can do.
    /// Rendering frame by frame with Apple's 3D map engine keeps memory per frame; the guard at 2800 MB stops a run
    /// cleanly and the stop message and progress line show the memory at the start of the render (see KNOWN_ISSUES).
    static let offersRenderInApp = true

    private var isRunning: Bool {
        mode == .preloading || mode == .preparing || mode == .playing || mode == .recording || mode == .finishing
    }

    var body: some View {
        let state = plan.state(at: flyTime)
        let frame = timeline.sample(at: state.routeElapsedSeconds)
        ZStack {
            theme.canvas.ignoresSafeArea()
            if plan.isUsable {
                if mode != .rendering {
                    flyMap(state: state, frame: frame)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if mode == .recording || mode == .playing || mode == .preloading { abortRun("Flyover stopped.") }
                        }
                }
                if mode != .rendering, state.phase == .follow, frame.position != nil {
                    // In the follow phase the camera is centred on the runner, so a dot fixed on the screen centre
                    // sits exactly on the route and cannot lag behind the camera (no tremble).
                    Color.clear.ignoresSafeArea().overlay { runnerBadge }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if mode == .rendering { renderScreen }
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
            // Only `.background` stops a run. The system permission alert for screen recording (and a pulled-down
            // Control Centre) only make the app `.inactive`, and stopping on that cancelled every first recording.
            if phase == .background && isRunning && mode != .finishing {
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

    private var runnerBadge: some View {
        Image(systemName: symbol)
            .font(.headline)
            .foregroundStyle(theme.routeCasing)
            .padding(8)
            .background(theme.route, in: Circle())
            .overlay(Circle().strokeBorder(theme.routeCasing, lineWidth: 2))
    }

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
            // Orbit (drop-in) and finish (pull-back): the camera is not on the runner, so the dot is a map annotation.
            // In the follow phase it is the fixed overlay in `body` instead (an annotation trembled there).
            if state.phase != .overview, state.phase != .follow, state.markerDrop < 1, let position = frame.position {
                Annotation("", coordinate: coordinate(position)) {
                    runnerBadge
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
            ZStack {
                // Brand logo across the top, part of the recorded screen.
                if isRunning && mode != .preparing && mode != .preloading { VideoLogoMark() }
                HStack {
                    if mode == .idle || mode == .done { closeButton }
                    Spacer()
                }
            }
            Spacer()
            if isRunning && mode != .preparing && mode != .preloading {
                VideoInfoCard(info: overlayInfo, progress: state.routeProgress)
            }
            if mode == .preparing || mode == .preloading {
                Text(mode == .preloading ? "Preparing map…" : "Starting recording…")
                    .font(MuryTypography.font(.subheadline, size: 15))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
            }
            if mode == .idle || mode == .done {
                panel
            }
        }
        .padding()
    }

    /// While rendering, the frame being made fills the screen, so the person watches the flyover
    /// come together. The progress sits in a translucent bar along the bottom edge.
    private var renderScreen: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            // The frames being made are not shown. With the bundled sample video it plays here like a short
            // advert; without it, a plain waiting screen.
            if RenderSampleVideo.isAvailable {
                RenderSampleVideo().ignoresSafeArea().accessibilityHidden(true)
                VStack {
                    Text("Making your flyover video…").font(MuryTypography.font(.headline, size: 17, weight: .semibold))
                        .foregroundStyle(.white).shadow(radius: 4)
                        .padding(.top, 60)
                    Text("Sample video, not your run").font(MuryTypography.font(.caption, size: 12))
                        .foregroundStyle(.white.opacity(0.8)).shadow(radius: 4)
                    Spacer()
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "film").font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
                    Text("Making your flyover video…").font(MuryTypography.font(.title3, size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            }
            renderBar
        }
    }

    private var renderBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendering your flyover (experimental)")
                .font(MuryTypography.font(.headline, size: 16, weight: .semibold))
            if let progress = renderProgress {
                ProgressView(value: Double(progress.frame), total: Double(max(progress.total, 1)))
                Text(renderStageText(progress))
                    .font(MuryTypography.font(.subheadline, size: 14))
                Text("Frame \(progress.frame) of \(progress.total) · \(String(format: "%.1f", progress.averageSecondsPerFrame)) s per frame · about \(Self.minutesText(progress.secondsRemaining)) left · \(progress.memoryMegabytes) MB (\(progress.stageText))")
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
            HStack {
                Text("Keep MURY open and the screen on. Nothing is recorded from the screen.")
                    .font(MuryTypography.font(.caption, size: 12))
                    .opacity(0.75)
                Spacer(minLength: 8)
                Button("Cancel", role: .cancel) {
                    cancelRender("Render cancelled.")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("flyover-render-cancel")
            }
        }
        .padding(.horizontal)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay { Color.black.opacity(0.25).clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)) }
                .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }

    /// What the flyover is showing at the frame being made, in plain words.
    private func renderStageText(_ progress: FlyoverRenderer.Progress) -> String {
        let share = Double(progress.frame) / Double(max(progress.total, 1))
        switch plan.state(at: plan.clipSeconds * share).phase {
        case .overview: return "Drawing the wide view of your route"
        case .orbit: return "Flying in to the start"
        case .follow: return "Following your run"
        case .finish: return "Pulling back out"
        }
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
            if Self.offersRenderInApp {
                Button {
                    startRender()
                } label: {
                    Label("Render in app (\(clip.rawValue) s)", systemImage: "film").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("flyover-render")
            }
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
            Text("Recording captures this screen while the flyover plays. Keep MURY open and tap the screen to stop. Satellite and 3D coverage depend on Apple Maps.")
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
        renderPreview = nil
        renderStartedAt = Date()
        mode = .rendering
        UIApplication.shared.isIdleTimerDisabled = true
        let renderPlan = FlyoverPlan(timeline: timeline, clipSeconds: Double(clip.rawValue))
        renderTask = Task {
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            do {
                let output = try await FlyoverRenderer.render(
                    plan: renderPlan, timeline: timeline, routeColor: UIColor(theme.route), symbolName: symbol,
                    overlayInfo: overlayInfo, reduceMotion: reduceMotion
                ) { progress in
                    renderProgress = progress
                    if let picture = progress.preview { renderPreview = picture }
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
        guard RPScreenRecorder.shared().isRecording else {
            message = "The system stopped the recording before the flyover ended. Tap Record video to try again."
            resetToStart()
            return
        }
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
