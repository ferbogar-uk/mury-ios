import CoreLocation
import Foundation
import Observation

/// Records an activity on the watch by itself: GPS from the watch, heart rate from its
/// sensor, nothing needed from the iPhone. The rules (time, distance, route, what counts
/// as a point) live in `WatchRecorderCore`, which is tested on Linux; this class only
/// connects it to CoreLocation, a one-second timer and the files on the watch.
@MainActor
@Observable
final class WatchRecorder: NSObject, CLLocationManagerDelegate {
    static let shared = WatchRecorder()

    /// What happened to the last recording, shown on the start screen.
    enum Outcome: Equatable {
        case saved(String)
        case tooShort
        case saveFailed
    }

    private(set) var core = WatchRecorderCore()
    /// Whole-second view of the clock, refreshed every second so the screen redraws.
    private(set) var now = Date()
    private(set) var outcome: Outcome?
    private(set) var locationDenied = false

    var state: WatchRecorderCore.State { core.state }
    var snapshot: MirrorSnapshot { core.snapshot(at: now) }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var heartRate: HeartRateReading?
    /// A recording that could not be written yet, kept so Retry does not lose it.
    @ObservationIgnored private var unsaved: WatchActivityRecord?
    @ObservationIgnored let store = WatchActivityStore(directory: WatchRecorder.directory)

    private static var directory: URL {
        URL.documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 3
    }

    /// The newest heart-rate reading, attached to the next route point. A stale one is not.
    func receive(_ reading: HeartRateReading) { heartRate = reading }

    func start(_ sport: WatchSport) {
        guard core.state == .idle else { return }
        outcome = nil
        unsaved = nil
        heartRate = nil
        locationDenied = false
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        core.start(sport: sport, at: Date())
        now = Date()
        manager.startUpdatingLocation()
        startTimer()
        sync()
    }

    func pause() {
        core.pause(at: Date())
        manager.stopUpdatingLocation()
        now = Date()
        sync()
    }

    func resume() {
        core.resume(at: Date())
        manager.startUpdatingLocation()
        now = Date()
        sync()
    }

    func finish() {
        manager.stopUpdatingLocation()
        stopTimer()
        let record = core.finish(at: Date())
        sync()
        guard let record else { return }
        if record.isTooShort { outcome = .tooShort; return }
        write(record)
    }

    func retrySave() {
        guard let unsaved else { return }
        write(unsaved)
    }

    private func write(_ record: WatchActivityRecord) {
        do {
            try store.save(record)
            unsaved = nil
            outcome = .saved(Self.summary(of: record))
        } catch {
            unsaved = record
            outcome = .saveFailed
        }
    }

    private static func summary(of record: WatchActivityRecord) -> String {
        "\(record.sport.label) \u{00B7} " + String(format: "%.2f km", record.distanceMeters / 1000)
    }

    /// Keeps the heart sensor in step with the recording.
    private func sync() {
        let monitor = HeartRateMonitor.shared
        if core.state != .idle { monitor.setSport(core.sport) }
        monitor.follow(core.state.mirrored)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        Task { @MainActor in self.locationDenied = denied }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in locations.forEach(self.record) }
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
        let fresh = HeartRateDisplay(heartRate, now: location.timestamp).isLive
        core.add(fix, at: location.timestamp, heartRate: fresh ? heartRate?.beatsPerMinute : nil)
    }
}
