import Foundation

/// The MapTiler map key used by the "Map cinema" test screen (the only place that talks to the internet).
///
/// The key is NOT in the source (the repository is public). The build workflows write it into
/// `larping/MapTilerKey.txt` from the GitHub secret `MAPTILER_API_KEY` before compiling, and the file is
/// listed in `.gitignore`. A build without the file (a local build, a fork) simply has no key and the
/// screen says so. A MapTiler key for a mobile app is visible inside the installed app anyway, so it is a
/// client key and not a secret in the strict sense; keep it restricted in the MapTiler account.
nonisolated enum MapTilerConfig {
    static let resourceName = "MapTilerKey"

    static var apiKey: String? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return clean(text)
    }

    /// Trims whitespace and rejects empty text. Foundation-only so it can be tested.
    static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
