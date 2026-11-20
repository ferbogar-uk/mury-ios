import XCTest

extension XCUIApplication {
    /// The app as most UI tests want it: the first-launch questions count as answered, so the
    /// tab bar appears even on a fresh simulator. Tests of the first launch itself set their own
    /// environment instead (see OnboardingTests and the theme tests).
    @MainActor
    static func skippingOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MURY_UI_TEST_SKIP_ONBOARDING"] = "1"
        return app
    }
}
