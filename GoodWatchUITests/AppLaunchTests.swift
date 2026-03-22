import XCTest

class AppLaunchTests: GWTestBase {

    func test_01_appLaunchesSuccessfully() {
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_02_landingScreenShowsPickForMe() {
        app.launch()
        XCTAssertTrue(app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5))
    }

    func test_03_landingScreenShowsExplore() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Explore & Search"].waitForExistence(timeout: 5))
    }

    func test_04_freshLaunchShowsOnboarding() {
        launchFresh()
        XCTAssertTrue(app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5))
    }

    func test_05_returningLaunchSkipsOnboarding() {
        // First launch - complete onboarding
        navigateToMainScreen()
        app.terminate()
        // Second launch - should go straight to main or landing, NOT onboarding mood picker
        launchReturning()
        // Should NOT see mood_card_0 immediately (onboarding skipped)
        sleep(2)
        XCTAssertFalse(app.buttons["mood_card_0"].exists,
            "Returning user should not see onboarding mood picker")
    }

    func test_06_appDoesNotCrashOnLaunch() {
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
        sleep(3)
        XCTAssertTrue(app.state == .runningForeground, "App should not crash within 3 seconds")
    }

    func test_07_appDoesNotCrashAfterForceQuit() {
        navigateToMainScreen()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_08_landingHasGoodWatchTitle() {
        app.launch()
        XCTAssertTrue(app.staticTexts["GoodWatch"].waitForExistence(timeout: 5))
    }

    func test_09_appLoadsWithinFiveSeconds() {
        let start = Date()
        app.launch()
        XCTAssertTrue(app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0, "App should reach landing within 5 seconds")
    }

    func test_10_noUIElementsOverlapOnLanding() {
        app.launch()
        XCTAssertTrue(app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["landing_pick_for_me"].isHittable)
    }
}
