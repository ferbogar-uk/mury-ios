import XCTest

final class HomeDashboardTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["theme-continue"].waitForExistence(timeout: 3) {
            app.buttons["theme-continue"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        return app
    }

    @MainActor
    func testHomeNavigationAndPersonalEmptyState() throws {
        let app = launchHome()
        for tab in ["Activities", "Record", "Stats", "Profile", "Home"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists)
        }
        XCTAssertTrue(app.staticTexts["Last 7 days"].exists)
        XCTAssertTrue(app.buttons["home-record-run"].exists)
        app.swipeUp()
        guard app.staticTexts["No personal activities yet"].exists else {
            throw XCTSkip("Empty/sample-only UI requires an install without real activities; this test never deletes owner data.")
        }
        XCTAssertTrue(app.staticTexts["Record an activity to see your progress here. Sample activities stay in Activities."].exists)
    }

    @MainActor
    func testRideShortcutRepeatsAndPreservesEditedIdleTitle() {
        let app = launchHome()
        app.buttons["home-record-ride"].tap()
        XCTAssertTrue(app.tabBars.buttons["Record"].isSelected)
        let menu = app.buttons["record-sport"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.label.contains("Ride"))
        // Resolve first-use location permission before the tap that focuses the field.
        let locationAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if locationAlert.waitForExistence(timeout: 3) {
            let allow = locationAlert.buttons["Allow While Using App"]
            if allow.exists { allow.tap() }
        }
        let title = app.textFields["record-event-name"]
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (title.value as? String ?? "").count))
        title.typeText("Home title survives\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        app.buttons["home-record-ride"].tap()
        XCTAssertEqual(title.value as? String, "Home title survives")
        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Record"].tap()
        XCTAssertEqual(title.value as? String, "Home title survives")
        menu.tap()
        app.buttons["Walk"].tap()
        XCTAssertTrue(menu.label.contains("Walk"))
        app.tabBars.buttons["Home"].tap()
        app.buttons["home-record-ride"].tap()
        XCTAssertTrue(menu.label.contains("Ride"))
    }
}
