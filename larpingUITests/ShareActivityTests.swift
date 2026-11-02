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
        XCTAssertTrue(activity.waitForExistence(timeout: 5), "Requires existing seeded Run activity; never recreates or deletes data.")
        activity.tap()
        app.buttons["activity-actions"].tap()
        app.buttons["activity-share"].tap()
        let picker = app.buttons["share-template"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        for template in ["Statistics", "Chips", "Route + stats", "Ticket", "Edge", "Receipt"] {
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
        let duration = app.segmentedControls["share-video-duration"]
        XCTAssertTrue(duration.exists)
        XCTAssertTrue(duration.buttons["30 s"].isSelected)
        for seconds in ["60 s", "15 s"] { duration.buttons[seconds].tap() }
        app.buttons["share-video-generate"].tap()
        XCTAssertTrue(app.buttons["share-video-cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.progressIndicators["share-video-progress"].exists)
        app.buttons["share-video-cancel"].tap()
        XCTAssertTrue(app.buttons["share-video-generate"].waitForExistence(timeout: 5))
        app.buttons["share-video-generate"].tap()
        XCTAssertTrue(app.buttons["share-video-share"].waitForExistence(timeout: 180))
        duration.buttons["30 s"].tap()
        XCTAssertTrue(app.buttons["share-video-generate"].waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Map"].firstMatch.tap()
        XCTAssertTrue(app.buttons["share-copy-png"].waitForExistence(timeout: 5))
    }
}
