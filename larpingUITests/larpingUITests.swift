import XCTest

final class larpingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFirstLaunchOffersSingleContinue() {
        let app = XCUIApplication()
        // Launch-domain values exercise onboarding without clearing owner data.
        app.launchArguments = ["-brandTheme", ""]
        app.launch()
        let button = app.buttons["theme-continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to MURY"].exists)
        XCTAssertTrue(app.staticTexts["Move. Explore. Achieve."].exists)
        XCTAssertFalse(app.buttons["theme-tiffany"].exists)
        XCTAssertFalse(app.buttons["theme-pink"].exists)
        XCTAssertTrue(button.isEnabled)
        button.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["theme-continue"].exists)
    }

    @MainActor
    func testUnknownStoredThemeShowsUsableWelcome() {
        let app = XCUIApplication()
        app.launchArguments = ["-brandTheme", "unknown"]
        app.launch()
        let button = app.buttons["theme-continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        button.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testLegacyMarkersSkipWelcomeAndPreserveDarkAppearance() {
        for marker in ["pink", "tiffany", "mury"] {
            let app = XCUIApplication()
            app.launchArguments = ["-brandTheme", marker, "-appearanceMode", "dark"]
            app.launch()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), marker)
            XCTAssertFalse(app.buttons["theme-continue"].exists)
            app.tabBars.buttons["Profile"].tap()
            app.buttons["profile-settings"].tap()
            let appearance = app.segmentedControls["profile-appearance"]
            XCTAssertTrue(appearance.waitForExistence(timeout: 5))
            XCTAssertTrue(appearance.buttons["Dark"].isSelected, marker)
            XCTAssertFalse(app.segmentedControls["profile-theme"].exists)
            app.terminate()
        }
    }

    @MainActor
    func testAppearancePersistsWithSingleIdentity() {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["theme-continue"].waitForExistence(timeout: 3) {
            app.buttons["theme-continue"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile-settings"].tap()
        let appearance = app.segmentedControls["profile-appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        for mode in ["System", "Light", "Dark"] {
            XCTAssertTrue(appearance.buttons[mode].exists)
            appearance.buttons[mode].tap()
            XCTAssertTrue(appearance.buttons[mode].isSelected)
        }
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["theme-continue"].exists)
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile-settings"].tap()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        XCTAssertTrue(appearance.buttons["Dark"].isSelected)
    }
}
