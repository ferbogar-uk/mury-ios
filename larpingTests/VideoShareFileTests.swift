import XCTest
@testable import larping

@MainActor
final class VideoShareFileTests: XCTestCase {
    func testMissingSourceThrows() {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        XCTAssertThrowsError(try VideoShareFile(source: source))
    }

    func testIndependentCopySurvivesSourceRemovalAndCleansUpOnRelease() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        let bytes = Data([0, 1, 2, 255])
        try bytes.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        var file: VideoShareFile? = try VideoShareFile(source: source)
        let sharedURL = try XCTUnwrap(file?.url)
        XCTAssertNotEqual(sharedURL, source)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try Data(contentsOf: sharedURL), bytes)
        file = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedURL.path))
    }
}
