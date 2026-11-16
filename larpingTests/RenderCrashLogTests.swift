import XCTest
@testable import larping

final class RenderCrashLogTests: XCTestCase {
    private func makeLog() -> (RenderCrashLog, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("crashlog-\(UUID().uuidString)")
        return (RenderCrashLog(directory: dir), dir)
    }

    func testNormalEndLeavesNothingBehind() {
        let (log, dir) = makeLog()
        defer { try? FileManager.default.removeItem(at: dir) }
        log.begin(total: 600, appVersion: "17", systemVersion: "26.1", device: "iPhone")
        log.update(frame: 5, phase: "orbit", megabytes: 300)
        log.clear()
        XCTAssertNil(log.interrupted())
    }

    func testKilledRenderLeavesLastSavedFrame() throws {
        let (log, dir) = makeLog()
        defer { try? FileManager.default.removeItem(at: dir) }
        log.begin(total: 600, appVersion: "17", systemVersion: "26.1", device: "iPhone")
        for frame in 1...232 { log.update(frame: frame, phase: "follow", megabytes: 100 + frame) }
        let crumb = try XCTUnwrap(log.interrupted())
        XCTAssertEqual(crumb.frame, 230)
        XCTAssertEqual(crumb.total, 600)
        XCTAssertEqual(crumb.megabytes, 330)
        XCTAssertEqual(crumb.samples.last, .init(frame: 230, megabytes: 330))
    }

    func testSamplesAreCapped() throws {
        let (log, dir) = makeLog()
        defer { try? FileManager.default.removeItem(at: dir) }
        log.begin(total: 2000, appVersion: "17", systemVersion: "26.1", device: "iPhone")
        for frame in 1...1000 { log.update(frame: frame, phase: "follow", megabytes: frame) }
        let crumb = try XCTUnwrap(log.interrupted())
        XCTAssertEqual(crumb.samples.count, RenderCrashLog.maxSamples)
        XCTAssertEqual(crumb.samples.last?.frame, 1000)
    }

    func testReportTextMentionsFrameMemoryAndDiagnostics() throws {
        let (log, dir) = makeLog()
        defer { try? FileManager.default.removeItem(at: dir) }
        log.begin(total: 600, appVersion: "17", systemVersion: "26.1", device: "iPhone")
        log.update(frame: 230, phase: "follow", megabytes: 1480)
        let crumb = try XCTUnwrap(log.interrupted())
        let text = RenderCrashLog.reportText(crumb, diagnostics: "{\"crash\":1}")
        XCTAssertTrue(text.contains("Frame 230 of 600"))
        XCTAssertTrue(text.contains("1480 MB"))
        XCTAssertTrue(text.contains("{\"crash\":1}"))
        XCTAssertFalse(RenderCrashLog.reportText(crumb, diagnostics: nil).contains("System diagnostics"))
    }

    func testDismissRemovesNoteAndDiagnostics() throws {
        let (log, dir) = makeLog()
        defer { try? FileManager.default.removeItem(at: dir) }
        log.begin(total: 10, appVersion: "17", systemVersion: "26.1", device: "iPhone")
        try Data("x".utf8).write(to: log.diagnosticsURL)
        log.dismiss()
        XCTAssertNil(log.interrupted())
        XCTAssertNil(log.diagnosticsText())
    }
}
