import XCTest

class PlatformSelectionTests: GWTestBase {

    func test_01_platformScreenIsReachable() {
        navigateToPlatformScreen()
        XCTAssertTrue(app.buttons["platform_continue"].exists,
            "Platform screen should be reachable from onboarding")
    }

    func test_02_selectAllButtonExists() {
        navigateToPlatformScreen()
        XCTAssertTrue(app.buttons["Select All"].waitForExistence(timeout: 5),
            "Platform screen should have Select All button")
    }

    func test_03_selectAllThenContinueWorks() {
        navigateToPlatformScreen()
        app.buttons["Select All"].tap()
        app.buttons["platform_continue"].tap()
        // Should advance to language screen
        XCTAssertTrue(app.staticTexts["English"].waitForExistence(timeout: 5),
            "Should advance to language screen after selecting all platforms")
    }

    func test_04_continueWithoutSelectionBlocked() {
        navigateToPlatformScreen()
        // Try continue without selecting any platform
        app.buttons["platform_continue"].tap()
        sleep(1)
        // Should still be on platform screen
        XCTAssertTrue(app.buttons["platform_continue"].exists,
            "Should not advance without selecting at least 1 platform")
    }

    func test_05_individualPlatformSelectable() {
        navigateToPlatformScreen()
        // Try selecting Netflix
        let netflix = app.buttons["platform_netflix"]
        if netflix.waitForExistence(timeout: 3) {
            netflix.tap()
            app.buttons["platform_continue"].tap()
            XCTAssertTrue(
                app.staticTexts["English"].waitForExistence(timeout: 5) ||
                app.buttons["language_lock"].waitForExistence(timeout: 5),
                "Single platform selection should allow continue")
        }
    }

    func test_06_multiplePlatformsSelectable() {
        navigateToPlatformScreen()
        // Select two platforms
        let netflix = app.buttons["platform_netflix"]
        let prime = app.buttons["platform_prime"]
        if netflix.waitForExistence(timeout: 3) { netflix.tap() }
        if prime.waitForExistence(timeout: 3) { prime.tap() }
        app.buttons["platform_continue"].tap()
        XCTAssertTrue(
            app.staticTexts["English"].waitForExistence(timeout: 5) ||
            app.buttons["language_lock"].waitForExistence(timeout: 5),
            "Multiple platform selection should allow continue")
    }

    func test_07_platformScreenShowsPlatformButtons() {
        navigateToPlatformScreen()
        // At least one platform button should exist
        let hasAnyPlatform =
            app.buttons["platform_netflix"].exists ||
            app.buttons["platform_prime"].exists ||
            app.buttons["platform_hotstar"].exists ||
            app.buttons["platform_jiocinema"].exists
        XCTAssertTrue(hasAnyPlatform,
            "Platform screen should show at least one platform option")
    }

    func test_08_selectAllDeselectAllToggle() {
        navigateToPlatformScreen()
        // Select all
        app.buttons["Select All"].tap()
        sleep(1)
        // Tap again to deselect
        if app.buttons["Deselect All"].exists {
            app.buttons["Deselect All"].tap()
            sleep(1)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Select/deselect toggle should not crash")
    }

    func test_09_platformScreenDoesNotCrash() {
        navigateToPlatformScreen()
        // Rapid tap platforms
        let platforms = ["platform_netflix", "platform_prime", "platform_hotstar"]
        for pid in platforms {
            if app.buttons[pid].exists { app.buttons[pid].tap() }
        }
        for pid in platforms {
            if app.buttons[pid].exists { app.buttons[pid].tap() }
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid platform toggling should not crash")
    }

    func test_10_platformContinueButtonIsHittable() {
        navigateToPlatformScreen()
        XCTAssertTrue(app.buttons["platform_continue"].isHittable,
            "Continue button should be hittable on platform screen")
    }
}
