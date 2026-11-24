import Foundation

/// The Mapbox public token for the map comparison test. It is empty in the repository: the TestFlight
/// workflow writes the `MAPBOX_ACCESS_TOKEN` secret here before building, so the token is never committed.
/// A public token (`pk.`) is meant to live inside apps; a secret token (`sk.`) must never be put here.
enum MapboxConfig {
    static let accessToken = ""
    static var isAvailable: Bool { accessToken.hasPrefix("pk.") }
}
