import MapKit
import SwiftUI

struct ActivityReplayView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeline: ReplayTimeline
    @State private var playback: ReplayPlayback
    @State private var camera: MapCameraPosition = .automatic
    @State private var cameraMode: CameraMode = .aerial

    private let savedDistance: String
    private let savedDuration: String
    private let symbol: String

    private enum CameraMode: String, CaseIterable {
        case aerial = "Aerial", topDown = "Top-down", free = "Free"
    }

    init(activity: CDActivity) {
        let snapshot = ReplayTimeline(points: activity.trackPoints.map {
            ReplayPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps)
        }, startedAt: activity.startedAt, endedAt: activity.endedAt)
        _timeline = State(initialValue: snapshot)
        _playback = State(initialValue: ReplayPlayback(duration: snapshot.duration))
        savedDistance = Formatters.distance(meters: activity.distanceMeters.map(Double.init))
        savedDuration = Formatters.duration(seconds: activity.durationSeconds)
        symbol = activity.sportType.symbolName
    }

    var body: some View {
        let frame = timeline.sample(at: playback.elapsedSeconds)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Experimental route replay").font(.headline)
                if timeline.segments.contains(where: { $0.count > 1 }) && timeline.duration > 0 {
                    replayMap(frame: frame)
                        .frame(height: 330)
                    controls(frame: frame)
                } else {
                    ContentUnavailableView("Replay unavailable", systemImage: "map",
                        description: Text("This activity needs at least two usable timed GPS points to replay."))
                }
                Text("Saved activity totals").font(.headline)
                Text("Distance: \(savedDistance) · Duration: \(savedDuration)")
                Text("Replay elapsed time includes gaps in saved timestamps; it is not moving time.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("3D buildings and terrain depend on Apple Maps coverage. Route overlays may flatten terrain. Choose Top-down for a 2D overview. This prototype does not avoid buildings or guarantee camera clearance.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(theme.canvas)
        .tint(theme.accent)
        .navigationTitle("Replay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { playback.pause(); dismiss() }
                    .accessibilityIdentifier("replay-close")
            }
        }
        .onChange(of: camera.positionedByUser) { _, byUser in
            if byUser { cameraMode = .free }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { playback.pause() }
        }
        .onDisappear { playback.pause() }
        .task(id: playback.isPlaying) {
            guard playback.isPlaying else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled && playback.isPlaying {
                do {
                    try await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 83))
                } catch { return }
                guard !Task.isCancelled, scenePhase == .active else {
                    playback.pause()
                    return
                }
                let now = clock.now
                let delta = previous.duration(to: now).components
                previous = now
                playback.advance(by: Double(delta.seconds) + Double(delta.attoseconds) / 1e18)
                updateCamera(frame: timeline.sample(at: playback.elapsedSeconds))
            }
        }
    }

    private func replayMap(frame: ReplayFrame) -> some View {
        Map(position: $camera) {
            ForEach(Array(timeline.segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.routeCasing, lineWidth: 8)
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.route.opacity(0.25), lineWidth: 4)
            }
            ForEach(Array(frame.revealedSegments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.routeCasing, lineWidth: 9)
                MapPolyline(coordinates: segment.map(coordinate))
                    .stroke(theme.route, lineWidth: 5)
            }
            if let position = frame.position {
                Annotation("Replay position", coordinate: coordinate(position)) {
                    Image(systemName: symbol)
                        .font(.headline)
                        .foregroundStyle(theme.routeCasing)
                        .padding(8)
                        .background(theme.route, in: Circle())
                        .overlay(Circle().strokeBorder(theme.routeCasing, lineWidth: 2))
                }
            }
        }
        .mapStyle(cameraMode == .topDown ? .standard(elevation: .flat) : .hybrid(elevation: .realistic))
        .accessibilityIdentifier("replay-map")
    }

    private func controls(frame: ReplayFrame) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Elapsed: \(Formatters.duration(seconds: Int(min(frame.elapsedSeconds, Double(Int.max / 2)))))")
                .monospacedDigit().accessibilityIdentifier("replay-elapsed")
            if frame.position == nil {
                Text("GPS gap — position unavailable").foregroundStyle(.secondary)
            }
            Text("Speed: \(Formatters.speed(metersPerSecond: frame.speedMps)) · Altitude: \(Formatters.elevation(meters: frame.altitudeMeters))")
                .font(.subheadline).monospacedDigit()
            Slider(value: Binding(get: { playback.elapsedSeconds }, set: {
                playback.seek(to: $0)
                updateCamera(frame: timeline.sample(at: playback.elapsedSeconds))
            }), in: 0...max(timeline.duration, 1), onEditingChanged: { editing in
                if editing { playback.pause() }
            })
            .accessibilityLabel("Replay elapsed time")
            .accessibilityIdentifier("replay-scrubber")
            Button {
                if playback.isPlaying { playback.pause() } else {
                    playback.play()
                    updateCamera(frame: timeline.sample(at: playback.elapsedSeconds))
                }
            } label: {
                Label(playback.isPlaying ? "Pause replay" : "Play replay",
                      systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("replay-play-pause")
            Picker("Replay speed", selection: Binding(get: { playback.speed }, set: { playback.setSpeed($0) })) {
                ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                    Text("\(Int(speed))x").tag(speed)
                }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("replay-speed")
            Picker("Camera mode", selection: $cameraMode) {
                ForEach(CameraMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("replay-camera")
            .onChange(of: cameraMode) { _, mode in
                if mode == .topDown { showOverview() }
                else if mode == .aerial { updateCamera(frame: frame) }
            }
            if cameraMode == .topDown {
                Text("2D overview").font(.caption)
            }
            Button("Return to Follow") {
                cameraMode = .aerial
                updateCamera(frame: frame)
            }
            .accessibilityIdentifier("replay-follow")
        }
        .padding()
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func coordinate(_ point: ReplayCoordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func showOverview() {
        let points = timeline.segments.flatMap { $0 }.map(coordinate)
        let rect = points.reduce(MKMapRect.null) { rect, point in
            let projected = MKMapPoint(point)
            return rect.union(MKMapRect(x: projected.x, y: projected.y, width: 1, height: 1))
        }
        camera = .rect(rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15))
    }

    private func updateCamera(frame: ReplayFrame) {
        guard cameraMode == .aerial, let position = frame.position else { return }
        camera = .camera(MapCamera(centerCoordinate: coordinate(position), distance: 700,
                                   heading: frame.headingDegrees ?? 0, pitch: reduceMotion ? 0 : 55))
    }
}
