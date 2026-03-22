import XCTest

class OnboardingTests: GWTestBase {

    func test_01_pickForMeButtonNavigatesToAuth() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_skip"].waitForExistence(timeout: 5))
    }

    func test_02_skipAuthNavigatesToMoodSelection() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5))
    }

    func test_03_moodSelectionShowsMultipleOptions() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mood_card_1"].exists)
    }

    func test_04_moodContinueRequiresSelection() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5))
        app.buttons["mood_continue"].tap()
        // Should still be on mood screen (no selection made)
        XCTAssertTrue(app.buttons["mood_card_0"].exists)
    }

    func test_05_moodSelectionAdvancesToPlatforms() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        XCTAssertTrue(app.buttons["platform_continue"].waitForExistence(timeout: 5))
    }

    func test_06_platformScreenHasSelectAll() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        XCTAssertTrue(app.buttons["Select All"].waitForExistence(timeout: 5))
    }

    func test_07_selectAllSelectsAllPlatforms() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        app.buttons["Select All"].waitForExistence(timeout: 5)
        app.buttons["Select All"].tap()
        app.buttons["platform_continue"].tap()
        XCTAssertTrue(app.staticTexts["English"].waitForExistence(timeout: 5))
    }

    func test_08_onboardingCompletionSavedAfterPreferences() {
        navigateToMainScreen()
        app.terminate()
        launchReturning()
        sleep(2)
        XCTAssertFalse(app.buttons["mood_card_0"].exists,
            "Onboarding should not repeat after completion")
    }

    func test_09_onboardingDoesNotRepeatOnSecondLaunch() {
        navigateToMainScreen()
        app.terminate()
        launchReturning()
        sleep(2)
        XCTAssertFalse(app.buttons["auth_skip"].exists,
            "Auth screen should not appear on second launch")
    }

    func test_10_onboardingDoesNotRepeatOnThirdLaunch() {
        navigateToMainScreen()
        app.terminate()
        launchReturning()
        app.terminate()
        launchReturning()
        sleep(2)
        XCTAssertFalse(app.buttons["mood_card_0"].exists,
            "Onboarding should not repeat on third launch")
    }

    func test_11_languageScreenAppearsAfterPlatforms() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        app.buttons["Select All"].waitForExistence(timeout: 5)
        app.buttons["Select All"].tap()
        app.buttons["platform_continue"].tap()
        XCTAssertTrue(app.staticTexts["English"].waitForExistence(timeout: 5))
    }

    func test_12_fullOnboardingFlowReachesMainScreen() {
        navigateToMainScreen()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].exists)
    }
}
