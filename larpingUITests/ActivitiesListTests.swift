import XCTest

/// The Activities list (build 38): sport filter chips narrow the cards to one sport.
final class ActivitiesListTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFilterChipShowsOnlyThatSport() throws {
        let app = XCUIApplication.skippingOnboarding()
        app.launch()
        if app.buttons["theme-continue"].waitForExistence(timeout: 3) { app.buttons["theme-continue"].tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Activities"].tap()
        let runChip = app.buttons["activity-filter-run"]
        guard runChip.waitForExistence(timeout: 5) else {
            throw XCTSkip("Needs at least two sports in the existing data; this test never adds or deletes data.")
        }
        runChip.tap()
        XCTAssertTrue(app.activityCard("run").waitForExistence(timeout: 3))
        let others = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'activity-row-' AND identifier != 'activity-row-run'"))
        XCTAssertEqual(others.count, 0)
        app.buttons["activity-filter-all"].tap()
        XCTAssertTrue(app.activityCard().waitForExistence(timeout: 3))
    }
}
