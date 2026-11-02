import Foundation

/// Owns a disk copy until the share controller and its consumer finish.
final class VideoShareFile: Identifiable {
    let id = UUID()
    let url: URL

    init(source: URL) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("MURY-share-" + UUID().uuidString + ".mp4")
        do {
            try FileManager.default.copyItem(at: source, to: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}
