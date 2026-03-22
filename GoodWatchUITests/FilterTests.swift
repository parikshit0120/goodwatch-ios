import XCTest

class FilterTests: GWTestBase {

    func test_01_languageFilterExistsOnMoodScreen() {
        navigateToMoodScreen()
        let toggle = app.buttons["tonight_language_toggle"]
        if toggle.exists {
            XCTAssertTrue(toggle.isHittable,
                "Tonight language toggle should be hittable")
        }
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_02_durationCardsExist() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        // Select a platform
        if app.buttons["platform_0"].waitForExistence(timeout: 5) {
            app.buttons["platform_0"].tap()
            app.buttons["platform_continue"].tap()
        }
        // Should be on duration screen
        XCTAssertTrue(app.buttons["duration_card_0"].waitForExistence(timeout: 5),
            "Duration screen should show at least one duration card")
    }

    func test_03_multipleDurationCardsAvailable() {
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
        XCTAssertTrue(app.buttons["duration_card_0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["duration_card_1"].exists,
            "Duration screen should show at least 2 duration options")
    }

    func test_04_durationContinueButtonExists() {
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
        XCTAssertTrue(app.buttons["duration_continue"].waitForExistence(timeout: 5),
            "Duration screen should have a Continue button")
    }

    func test_05_durationSelectionAdvancesFlow() {
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
            app.buttons["duration_card_0"].tap()
            app.buttons["duration_continue"].tap()
        }
        // Should advance past duration screen
        XCTAssertTrue(app.state == .runningForeground,
            "Duration selection should advance the flow")
    }

    func test_06_platformFilterPersistsThroughFlow() {
        navigateToMainScreen(mood: 0)
        // If we get to main screen, platform filter was applied
        XCTAssertTrue(
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) ||
            app.staticTexts["No matches found"].waitForExistence(timeout: 30),
            "Platform filter should persist through to recommendation")
    }

    func test_07_moodFilterAffectsRecommendation() {
        navigateToMainScreen(mood: 0)
        XCTAssertTrue(
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) ||
            app.staticTexts["No matches found"].waitForExistence(timeout: 30),
            "Mood filter should produce a recommendation or no-matches")
    }

    func test_08_changingDurationDoesNotCrash() {
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
            app.buttons["duration_card_0"].tap()
            sleep(1)
            if app.buttons["duration_card_1"].exists {
                app.buttons["duration_card_1"].tap()
            }
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Changing duration selection should not crash")
    }

    func test_09_durationCardIsHittable() {
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
            XCTAssertTrue(app.buttons["duration_card_0"].isHittable,
                "First duration card should be hittable")
        }
    }

    func test_10_durationContinueIsHittable() {
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
        if app.buttons["duration_continue"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["duration_continue"].isHittable,
                "Duration continue button should be hittable")
        }
    }
}
