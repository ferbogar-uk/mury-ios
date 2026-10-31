import XCTest
@testable import larping

@MainActor
final class ShareVideoComposerTests: XCTestCase {
    func testCancelledExportDoesNotReturnAVideo() async {
        let stats = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Run", distance: "1 km", duration: "5:00", paceOrSpeed: "5:00", date: "Jan 1, 2026")
        let task = Task {
            try await ShareVideoComposer.composeVideo(snapshot: nil, coordinates: [], stats: stats, style: BrandTheme.pink.shareStyle(for: .light))
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled export must not produce a shareable video")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}
