import XCTest

final class larpingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFirstLaunchRequiresExplicitChoice() throws {
        let app = XCUIApplication()
        app.launch()
        let button = app.buttons["theme-continue"]
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("Run on a clean simulator install to verify first launch; existing activity data is never reset by this test.")
        }
        XCTAssertTrue(app.staticTexts["Welcome to MURY"].exists)
        XCTAssertTrue(app.buttons["theme-tiffany"].exists)
        XCTAssertTrue(app.buttons["theme-pink"].exists)
        XCTAssertFalse(button.isEnabled)
        app.buttons["theme-tiffany"].tap()
        XCTAssertTrue(button.isEnabled)
        button.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testUnknownStoredThemeRequiresExplicitChoice() {
        let app = XCUIApplication()
        // A launch-domain preference leaves the existing persistent store intact.
        app.launchArguments = ["-brandTheme", "unknown"]
        app.launch()
        XCTAssertTrue(app.buttons["theme-continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["theme-continue"].isEnabled)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.terminate()
    }

    @MainActor
    func testThemeAndAppearanceAreIndependentAndPersist() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["theme-pink"].waitForExistence(timeout: 3) {
            app.buttons["theme-pink"].tap()
            app.buttons["theme-continue"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile-settings"].tap()
        let themes = app.segmentedControls["profile-theme"]
        XCTAssertTrue(themes.waitForExistence(timeout: 5))
        let appearance = app.segmentedControls["profile-appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        for mode in ["System", "Light", "Dark"] {
            XCTAssertTrue(appearance.buttons[mode].exists)
        }
        themes.buttons["Pink"].tap()
        appearance.buttons["Dark"].tap()
        XCTAssertTrue(themes.buttons["Pink"].isSelected)
        themes.buttons["Tiffany Blue"].tap()
        XCTAssertTrue(appearance.buttons["Dark"].isSelected)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["theme-continue"].exists)
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile-settings"].tap()
        XCTAssertTrue(app.segmentedControls["profile-theme"].buttons["Tiffany Blue"].isSelected)
        XCTAssertTrue(appearance.buttons["Dark"].isSelected)
    }
}
