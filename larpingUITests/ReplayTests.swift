import XCTest

final class ReplayTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testReplayControlsAndReopenPaused() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["theme-continue"].waitForExistence(timeout: 3) {
            app.buttons["theme-continue"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Activities"].tap()
        let activity = app.cells.firstMatch
        guard activity.waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires an existing activity, such as the first-launch samples. No data is inserted or deleted.")
        }
        // Select an existing Run row; sample data is never recreated or deleted.
        let link = app.cells.containing(.staticText, identifier: "Run").firstMatch
        guard link.exists else {
            throw XCTSkip("No existing Run sample is visible; this test never resets owner data.")
        }
        link.tap()
        let open = app.buttons["activity-replay"]
        guard open.waitForExistence(timeout: 5) else {
            throw XCTSkip("The selected activity has no replayable route.")
        }
        open.tap()
        let play = app.buttons["replay-play-pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play replay")
        play.tap()
        XCTAssertEqual(play.label, "Pause replay")
        play.tap()
        app.sliders["replay-scrubber"].adjust(toNormalizedSliderPosition: 0.5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.35)))
        app.segmentedControls["replay-speed"].buttons["2x"].tap()
        XCTAssertTrue(app.segmentedControls["replay-speed"].buttons["2x"].isSelected)
        app.segmentedControls["replay-camera"].buttons["Top-down"].tap()
        app.segmentedControls["replay-camera"].buttons["Free"].tap()
        app.buttons["replay-follow"].tap()
        XCTAssertTrue(app.segmentedControls["replay-camera"].buttons["Aerial"].isSelected)
        app.buttons["replay-close"].tap()
        open.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play replay")
    }
}
