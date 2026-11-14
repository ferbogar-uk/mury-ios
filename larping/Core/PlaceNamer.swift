import CoreLocation
import Foundation

/// Finds the neighbourhood or town for a coordinate, to put in an activity's title.
///
/// This is the only place the app sends anything to Apple: one coordinate of the activity,
/// no account and nothing stored. Without a network, or when the answer is slow, it returns
/// nil and the title simply has no place.
enum PlaceNamer {
    static func name(latitude: Double, longitude: Double) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await lookup(latitude: latitude, longitude: longitude) }
            group.addTask {
                try? await Task.sleep(for: .seconds(6))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func lookup(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return mark.subLocality ?? mark.locality
    }
}
