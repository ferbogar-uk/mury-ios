import Foundation
import HealthKit

/// Asks Health to wake MURY when a new workout is saved (for example one recorded in the Apple Exercise
/// app), so it can import it. This is an extra: the guaranteed path is the sync that runs whenever MURY
/// opens. If Health does not deliver in the background, new workouts simply appear the next time the app opens.
@MainActor
enum HealthBackgroundDelivery {
    private static var query: HKObserverQuery?

    static func start(store: ActivitiesStore) {
        guard HealthKitService.isAvailable, query == nil else { return }
        let health = HKHealthStore()
        let observer = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task { @MainActor in
                _ = await HealthSync.run(store: store)
                completion()
            }
        }
        query = observer
        health.execute(observer)
        health.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { _, _ in }
    }
}
