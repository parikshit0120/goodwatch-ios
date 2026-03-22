import XCTest

class MoodSelectionTests: GWTestBase {

    func test_01_moodScreenShowsMoodCards() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_card_0"].exists,
            "Mood screen should show at least one mood card")
    }

    func test_02_multipleMoodsAvailable() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_card_0"].exists)
        XCTAssertTrue(app.buttons["mood_card_1"].exists,
            "Mood screen should show at least 2 mood options")
    }

    func test_03_moodContinueButtonExists() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_continue"].exists,
            "Mood screen should have a Continue button")
    }

    func test_04_singleMoodSelection() {
        navigateToMoodScreen()
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        // Should advance to platform screen
        XCTAssertTrue(app.buttons["platform_continue"].waitForExistence(timeout: 5),
            "Selecting a mood and tapping continue should advance to platforms")
    }

    func test_05_changeMoodBeforeContinue() {
        navigateToMoodScreen()
        app.buttons["mood_card_0"].tap()
        sleep(1)
        // Change selection to mood 1
        app.buttons["mood_card_1"].tap()
        app.buttons["mood_continue"].tap()
        // Should still advance
        XCTAssertTrue(app.buttons["platform_continue"].waitForExistence(timeout: 5),
            "Changing mood before continue should work")
    }

    func test_06_continueWithoutSelectionDoesNotAdvance() {
        navigateToMoodScreen()
        app.buttons["mood_continue"].tap()
        // Should still be on mood screen
        XCTAssertTrue(app.buttons["mood_card_0"].exists,
            "Continue without mood selection should stay on mood screen")
    }

    func test_07_moodScreenDoesNotCrashOnRapidTapping() {
        navigateToMoodScreen()
        for i in 0..<4 {
            if app.buttons["mood_card_\(i)"].exists {
                app.buttons["mood_card_\(i)"].tap()
            }
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid mood selection should not crash")
    }

    func test_08_moodCardIsHittable() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_card_0"].isHittable,
            "First mood card should be hittable")
    }

    func test_09_moodContinueIsHittable() {
        navigateToMoodScreen()
        XCTAssertTrue(app.buttons["mood_continue"].isHittable,
            "Continue button should be hittable on mood screen")
    }

    func test_10_tonightLanguageToggleExists() {
        navigateToMoodScreen()
        // Check if tonight language toggle exists (optional feature)
        let toggle = app.buttons["tonight_language_toggle"]
        if toggle.exists {
            XCTAssertTrue(toggle.isHittable,
                "Tonight language toggle should be hittable if visible")
        }
        XCTAssertTrue(app.state == .runningForeground)
    }
}
