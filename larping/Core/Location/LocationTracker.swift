import CoreLocation
import Observation

/// Wraps `CLLocationManager` for a single recording session. A `class`
/// (not a struct/actor) because `CLLocationManagerDelegate` needs identity
/// and callbacks arrive off the main actor.
@MainActor
@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    enum RecordingState {
        case idle, recording, paused
    }

    private(set) var state: RecordingState = .idle
    private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    private var math = RecorderMath()
    var distanceMeters: Double { math.distanceMeters }
    var currentSpeedMps: Double { math.currentSpeedMps }
    var maxSpeedMps: Double { math.maxSpeedMps }
    var elevationGainMeters: Double { math.elevationGainMeters }
    var isGPSDegraded: Bool { math.isGPSDegraded }
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var elapsedSeconds = 0

    private var trackPoints: [TrackPointPayload] = []
    private let manager = CLLocationManager()
    private var startedAt: Date?
    /// Active (moving) time, in whole seconds, not counting pauses — the
    /// single source of truth for the on-screen timer AND the stored
    /// `durationSeconds`. `activeTime` keeps the precise sub-second
    /// accumulation across segments; `elapsedSeconds` is its whole-second view.
    private var activeTime: TimeInterval = 0
    private var segmentStart: Date?
    private var displayTimer: Timer?

    /// Clock seam so tests can drive start/pause/resume/finish
    /// deterministically without real sleeps.
    private let currentDate: () -> Date

    private static let isoFormatter = ISO8601DateFormatter()

    init(currentDate: @escaping () -> Date = { Date() }) {
        self.currentDate = currentDate
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard state != .recording else { return }
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        state = .recording
        startedAt = currentDate()
        trackPoints = []
        routeCoordinates = []
        math = RecorderMath()
        activeTime = 0
        elapsedSeconds = 0
        segmentStart = currentDate()
        startDisplayTimer()
        manager.startUpdatingLocation()
    }

    func pause() {
        guard state == .recording else { return }
        if let segmentStart {
            activeTime += currentDate().timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        elapsedSeconds = Int(activeTime)
        state = .paused
        stopDisplayTimer()
        manager.stopUpdatingLocation()
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording
        segmentStart = currentDate()
        startDisplayTimer()
        manager.startUpdatingLocation()
    }

    struct Recording {
        let startedAt: Date
        let endedAt: Date
        /// Active (moving) duration — pause time excluded.
        let activeDurationSeconds: TimeInterval
        let durationSeconds: Int
        let trackPoints: [TrackPointPayload]
        let distanceMeters: Double
        let elevationGainMeters: Double
        let maxSpeedMps: Double
    }

    func stop() -> Recording {
        if state == .recording, let segmentStart {
            activeTime += currentDate().timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        elapsedSeconds = Int(activeTime)
        stopDisplayTimer()
        manager.stopUpdatingLocation()
        let recording = Recording(
            startedAt: startedAt ?? currentDate(),
            endedAt: currentDate(),
            activeDurationSeconds: activeTime,
            durationSeconds: Int(activeTime),
            trackPoints: trackPoints,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            maxSpeedMps: maxSpeedMps
        )
        state = .idle
        startedAt = nil
        activeTime = 0
        elapsedSeconds = 0
        return recording
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func tick() {
        guard state == .recording, let segmentStart else { return }
        elapsedSeconds = Int(activeTime + currentDate().timeIntervalSince(segmentStart))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locations.forEach(self.record)
        }
    }

    private func record(_ location: CLLocation) {
        let fix = GPSFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed
        )
        guard math.add(fix, isRecording: state == .recording) == .accepted else { return }

        routeCoordinates.append(location.coordinate)
        trackPoints.append(
            TrackPointPayload(
                timestamp: Self.isoFormatter.string(from: location.timestamp),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                speedMps: location.speed >= 0 ? location.speed : nil,
                heartRateBpm: nil,
                cadenceRpm: nil
            )
        )
    }
}
