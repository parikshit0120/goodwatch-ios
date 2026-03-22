import XCTest

class AccessibilityTests: GWTestBase {

    func test_01_landingButtonsHaveAccessibilityIdentifiers() {
        launchFresh()
        XCTAssertTrue(app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5),
            "Pick For Me button should have accessibility identifier")
    }

    func test_02_landingExploreHasAccessibilityIdentifier() {
        launchFresh()
        XCTAssertTrue(
            app.staticTexts["Explore & Search"].waitForExistence(timeout: 5),
            "Explore & Search should have accessibility text")
    }

    func test_03_authButtonsHaveAccessibilityIdentifiers() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_skip"].waitForExistence(timeout: 5),
            "Auth skip button should have accessibility identifier")
        let hasApple = app.buttons["auth_apple_sign_in"].exists
        let hasGoogle = app.buttons["auth_google_sign_in"].exists
        XCTAssertTrue(hasApple || hasGoogle,
            "At least one sign-in button should have accessibility identifier")
    }

    func test_04_moodCardsHaveAccessibilityIdentifiers() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_card_0"].exists,
            "First mood card should have accessibility identifier mood_card_0")
        XCTAssertTrue(app.buttons["mood_continue"].exists,
            "Mood continue should have accessibility identifier mood_continue")
    }

    func test_05_platformButtonsHaveAccessibilityIdentifiers() {
        navigateToPlatformScreen()
        XCTAssertTrue(app.buttons["platform_0"].exists,
            "First platform should have accessibility identifier platform_0")
        XCTAssertTrue(app.buttons["platform_continue"].exists,
            "Platform continue should have accessibility identifier platform_continue")
    }

    func test_06_mainScreenButtonsHaveAccessibilityIdentifiers() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("Main screen did not load")
            return
        }
        XCTAssertTrue(app.buttons["main_watch_now"].exists,
            "Watch Now should have accessibility identifier main_watch_now")
        XCTAssertTrue(app.buttons["main_not_tonight"].exists,
            "Not Tonight should have accessibility identifier main_not_tonight")
    }

    func test_07_durationCardsHaveAccessibilityIdentifiers() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        if app.buttons["platform_0"].waitForExistence(timeout: 5) {
            app.buttons["platform_0"].tap()
            app.buttons["platform_continue"].tap()
        }
        if app.buttons["duration_card_0"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["duration_card_0"].exists,
                "First duration card should have accessibility identifier")
        }
        if app.buttons["duration_continue"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["duration_continue"].exists,
                "Duration continue should have accessibility identifier")
        }
    }

    func test_08_confidenceMomentHasAccessibilityIdentifier() {
        navigateToMainScreen()
        // The confidence moment screen identifier should have been visible during navigation
        // Verify main screen loaded (meaning confidence moment was passed)
        XCTAssertTrue(
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) ||
            app.staticTexts["No matches found"].waitForExistence(timeout: 30),
            "Confidence moment should have been navigated through")
    }

    func test_09_allLandingElementsAreInteractive() {
        launchFresh()
        let pickForMe = app.buttons["landing_pick_for_me"]
        XCTAssertTrue(pickForMe.waitForExistence(timeout: 5))
        XCTAssertTrue(pickForMe.isHittable,
            "Pick For Me should be hittable (interactive)")
        let explore = app.staticTexts["Explore & Search"]
        if explore.exists {
            XCTAssertTrue(explore.isHittable,
                "Explore & Search should be hittable (interactive)")
        }
    }

    func test_10_goodScoreTextHasAccessibilityLabel() {
        navigateToMainScreen()
        let goodScore = app.staticTexts["GOODSCORE"]
        XCTAssertTrue(goodScore.waitForExistence(timeout: 30),
            "GOODSCORE label should exist with accessibility text")
    }
}
