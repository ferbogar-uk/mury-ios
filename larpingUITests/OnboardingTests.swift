import XCTest

final class OnboardingTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MURY_UI_TEST_BRAND_THEME"] = "mury"
        app.launchEnvironment["MURY_UI_TEST_SHOW_ONBOARDING"] = "1"
        app.launch()
        return app
    }

    @MainActor
    func testSkippingHealthStillFinishesWithManualProfile() {
        let app = launchOnboarding()
        let skip = app.buttons["onboarding-skip-health"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()

        let next = app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "profile is incomplete, Continue must wait")

        app.buttons["profile-add-birthdate"].tap()
        app.segmentedControls["profile-sex"].buttons["Female"].tap()
        let height = app.textFields["profile-height"]
        height.tap(); height.typeText("170")
        let weight = app.textFields["profile-weight"]
        weight.tap(); weight.typeText("65")
        XCTAssertTrue(next.isEnabled)
        next.tap()

        let finish = app.buttons["onboarding-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testAbsurdHeightKeepsContinueDisabled() {
        let app = launchOnboarding()
        XCTAssertTrue(app.buttons["onboarding-skip-health"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-health"].tap()
        app.buttons["profile-add-birthdate"].tap()
        app.segmentedControls["profile-sex"].buttons["Male"].tap()
        let height = app.textFields["profile-height"]
        height.tap(); height.typeText("900")
        let weight = app.textFields["profile-weight"]
        weight.tap(); weight.typeText("70")
        XCTAssertFalse(app.buttons["onboarding-continue"].isEnabled)
    }
}
