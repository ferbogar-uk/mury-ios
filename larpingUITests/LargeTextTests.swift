import XCTest

/// Opens the main tabs at the largest accessibility text size. It proves the screens load and stay
/// usable at that size; it cannot judge clipping by eye, so a look on a phone is still needed.
final class LargeTextTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testMainTabsOpenAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchEnvironment["MURY_UI_TEST_BRAND_THEME"] = "mury"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        for name in ["Activities", "Stats", "Profile", "Home"] {
            let tab = tabs.buttons[name]
            // At this text size a tab switch can take a moment on a slow CI simulator.
            XCTAssertTrue(tab.waitForExistence(timeout: 10), name)
            tab.tap()
            let selected = NSPredicate(format: "isSelected == true")
            let wait = XCTNSPredicateExpectation(predicate: selected, object: tab)
            XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, name)
        }
    }
}
