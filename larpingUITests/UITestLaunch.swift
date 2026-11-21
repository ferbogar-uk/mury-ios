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

    /// An activity card in the Activities list (`activity-row-<sport>`), or any card when `sport` is nil.
    @MainActor
    func activityCard(_ sport: String? = nil) -> XCUIElement {
        let predicate = sport.map { NSPredicate(format: "identifier == %@", "activity-row-" + $0) }
            ?? NSPredicate(format: "identifier BEGINSWITH %@", "activity-row-")
        return descendants(matching: .any).matching(predicate).firstMatch
    }
}
