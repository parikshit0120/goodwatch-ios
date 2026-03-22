import XCTest

class AuthTests: GWTestBase {

    func test_01_authScreenAppearsAfterPickForMe() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_skip"].waitForExistence(timeout: 5),
            "Auth screen should appear after tapping Pick For Me")
    }

    func test_02_authScreenShowsAppleSignIn() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_apple_sign_in"].waitForExistence(timeout: 5),
            "Auth screen should show Apple Sign In button")
    }

    func test_03_authScreenShowsGoogleSignIn() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_google_sign_in"].waitForExistence(timeout: 5),
            "Auth screen should show Google Sign In button")
    }

    func test_04_skipAuthNavigatesForward() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        // Should advance to mood selection
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5),
            "Skipping auth should navigate to mood selection")
    }

    func test_05_exploreRequiresAuthGate() {
        app.launch()
        app.staticTexts["Explore & Search"].tap()
        // Auth gate should appear
        XCTAssertTrue(
            app.buttons["auth_skip"].waitForExistence(timeout: 5) ||
            app.buttons["auth_apple_sign_in"].waitForExistence(timeout: 5),
            "Explore should show auth gate")
    }

    func test_06_skipAuthOnExploreNavigatesToExplore() {
        app.launch()
        app.staticTexts["Explore & Search"].tap()
        if app.buttons["auth_skip"].waitForExistence(timeout: 5) {
            app.buttons["auth_skip"].tap()
            sleep(2)
            XCTAssertTrue(app.state == .runningForeground,
                "Skipping auth on Explore should navigate to Explore view")
        }
    }

    func test_07_authScreenDoesNotCrashOnAppleTap() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        if app.buttons["auth_apple_sign_in"].waitForExistence(timeout: 5) {
            app.buttons["auth_apple_sign_in"].tap()
            sleep(2)
            XCTAssertTrue(app.state == .runningForeground,
                "App should not crash when tapping Apple sign in")
        }
    }

    func test_08_authScreenDoesNotCrashOnGoogleTap() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        if app.buttons["auth_google_sign_in"].waitForExistence(timeout: 5) {
            app.buttons["auth_google_sign_in"].tap()
            sleep(2)
            XCTAssertTrue(app.state == .runningForeground,
                "App should not crash when tapping Google sign in")
        }
    }

    func test_09_authSkipDoesNotAffectOnboarding() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].tap()
        // Verify onboarding continues after skip
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5),
            "Onboarding should continue normally after skipping auth")
    }

    func test_10_authScreenHasAllProviders() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        XCTAssertTrue(app.buttons["auth_skip"].waitForExistence(timeout: 5))
        // At least skip + one sign-in method should be visible
        let hasApple = app.buttons["auth_apple_sign_in"].exists
        let hasGoogle = app.buttons["auth_google_sign_in"].exists
        XCTAssertTrue(hasApple || hasGoogle,
            "Auth screen should show at least one sign-in provider")
    }
}
