import XCTest

final class ShareActivityTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testTransparentTemplatesMetricSelectionAndPNGCopy() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["theme-continue"].waitForExistence(timeout: 3) {
            app.buttons["theme-continue"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Activities"].tap()
        let activity = app.cells.containing(.staticText, identifier: "Run").firstMatch
        guard activity.waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires an existing Run activity. This test never recreates or deletes data.")
        }
        activity.tap()
        app.buttons["activity-actions"].tap()
        app.buttons["activity-share"].tap()
        let picker = app.buttons["share-template"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        for template in ["Statistics", "Compact", "Route + stats"] {
            picker.tap()
            app.buttons[template].firstMatch.tap()
            XCTAssertTrue(app.buttons["share-metrics"].exists)
            app.buttons["share-copy-png"].tap()
            XCTAssertTrue(app.staticTexts["share-copy-success"].waitForExistence(timeout: 5))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "MURY sharing \(template)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.buttons["share-metrics"].tap()
        let distance = app.buttons["share-metric-distance"]
        XCTAssertTrue(distance.waitForExistence(timeout: 3))
        distance.tap()
        app.buttons["share-copy-png"].tap()
        XCTAssertTrue(app.staticTexts["share-copy-success"].waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Classic"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Gallery"].exists)
        XCTAssertFalse(app.buttons["share-metrics"].exists)
        picker.tap()
        app.buttons["Video"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Generate video"].exists)
        XCTAssertFalse(app.buttons["share-copy-png"].exists)
    }
}
