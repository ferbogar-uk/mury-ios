import Foundation
import HealthKit
import Observation

/// Measures the heart rate on the watch and hands every reading to `onReading`.
///
/// The iPhone is still the one recording. The watch only runs a workout session because
/// that is what makes the heart-rate sensor sample continuously, and it throws the
/// session's own data away at the end, so Health never gets a second copy of the workout.
/// What to do and when comes from `HeartRateSensorPlan`, which is tested on Linux; this
/// file is only the part that talks to HealthKit.
@MainActor
@Observable
final class HeartRateMonitor: NSObject {
    static let shared = HeartRateMonitor()

    /// The newest valid reading, or nil when there is none yet.
    private(set) var latest: HeartRateReading?
    private(set) var sensor: HeartRateSensorState = .stopped
    /// Set when the person refused the permission, so we stop asking on every recording.
    private(set) var denied = false

    @ObservationIgnored var onReading: ((HeartRateReading) -> Void)?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    /// Follows what the iPhone is recording. Safe to call on every change.
    func follow(_ mirrored: MirrorSnapshot.State) {
        switch HeartRateSensorPlan.action(mirrored: mirrored, sensor: sensor) {
        case .start:
            guard !denied else { return }
            // Marked as running at once so a second call during the start does not start twice.
            sensor = .running
            Task { await begin() }
        case .pause:
            session?.pause()
            sensor = .paused
        case .resume:
            session?.resume()
            sensor = .running
        case .stop:
            stop()
        case .nothing:
            break
        }
    }

    private func begin() async {
        guard HKHealthStore.isHealthDataAvailable() else { fail(denied: false); return }
        let heartRate = HKQuantityType(.heartRate)
        let workout = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [workout], read: [heartRate])
        } catch {
            fail(denied: true)
            return
        }
        if store.authorizationStatus(for: workout) == .sharingDenied {
            fail(denied: true)
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
        } catch {
            fail(denied: false)
        }
    }

    private func stop() {
        sensor = .stopped
        latest = nil
        let session = self.session
        let builder = self.builder
        self.session = nil
        self.builder = nil
        session?.end()
        Task {
            // The iPhone owns the workout. Throwing this one away keeps Health from
            // getting a duplicate.
            try? await builder?.endCollection(at: Date())
            builder?.discardWorkout()
        }
    }

    private func fail(denied: Bool) {
        if denied { self.denied = true }
        session?.end()
        session = nil
        builder = nil
        sensor = .stopped
    }

    private func receive(bpm: Double, date: Date) {
        // A glitch is dropped here: the screen keeps the last good reading until it goes stale.
        guard let reading = HeartRateReading(beatsPerMinute: bpm, date: date) else { return }
        latest = reading
        onReading?(reading)
    }
}

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.fail(denied: false) }
    }
}

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let type = HKQuantityType(.heartRate)
        guard collectedTypes.contains(type),
              let statistics = workoutBuilder.statistics(for: type),
              let quantity = statistics.mostRecentQuantity()
        else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
        Task { @MainActor in self.receive(bpm: bpm, date: date) }
    }
}