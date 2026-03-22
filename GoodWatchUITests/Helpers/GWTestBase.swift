import XCTest

class GWTestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--interaction-points", "1000",
            "--reset-onboarding",
            "--skip-loading-delay"
        ]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Navigation helpers

    func launchFresh() {
        app.launchArguments = [
            "--interaction-points", "1000",
            "--reset-onboarding",
            "--skip-loading-delay"
        ]
        app.launch()
    }

    func launchReturning() {
        app.launchArguments = [
            "--interaction-points", "1000",
            "--skip-loading-delay"
        ]
        app.launch()
    }

    func navigateToMainScreen(mood: Int = 0) {
        app.launch()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        // Select mood
        let moodCards = app.buttons.matching(identifier: "mood_card_\(mood)")
        if moodCards.count > 0 { moodCards.firstMatch.tap() }
        app.buttons["mood_continue"].tap()
        // Select all platforms
        if app.buttons["Select All"].exists { app.buttons["Select All"].tap() }
        app.buttons["platform_continue"].tap()
        // Language
        if app.staticTexts["English"].exists { app.staticTexts["English"].tap() }
        if app.buttons["language_lock"].exists { app.buttons["language_lock"].tap() }
        // Duration
        let durationCards = app.buttons.matching(identifier: "duration_card_0")
        if durationCards.count > 0 { durationCards.firstMatch.tap() }
        if app.buttons["duration_continue"].exists { app.buttons["duration_continue"].tap() }
        // Wait for recommendation
        let goodscore = app.staticTexts["GOODSCORE"]
        XCTAssertTrue(goodscore.waitForExistence(timeout: 20), "Main screen should show GOODSCORE")
    }

    func navigateToExplore() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Explore & Search"].waitForExistence(timeout: 5))
        app.staticTexts["Explore & Search"].tap()
        // Auth gate - skip
        if app.buttons["auth_skip"].waitForExistence(timeout: 3) {
            app.buttons["auth_skip"].tap()
        }
    }

    func navigateToPlatformScreen() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        let moodCards = app.buttons.matching(identifier: "mood_card_0")
        if moodCards.count > 0 { moodCards.firstMatch.tap() }
        app.buttons["mood_continue"].tap()
        XCTAssertTrue(app.buttons["platform_continue"].waitForExistence(timeout: 5))
    }

    func navigateToMoodScreen() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5))
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    func getMovieTitle() -> String {
        return app.staticTexts.allElementsBoundByIndex
            .filter { $0.label.count > 3 && $0.label != "GOODSCORE" }
            .first?.label ?? ""
    }
}
