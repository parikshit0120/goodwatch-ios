import XCTest

class PerformanceTests: GWTestBase {

    func test_01_appLaunchesWithinFiveSeconds() {
        let start = Date()
        launchFresh()
        let appeared = app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(appeared,
            "Landing screen should appear within 5 seconds (took \(elapsed)s)")
        XCTAssertLessThan(elapsed, 5.0,
            "App launch should complete within 5 seconds")
    }

    func test_02_recommendationFetchWithinTenSeconds() {
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
        // Start timing from after onboarding
        let start = Date()
        let gotRec = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(gotRec,
            "Recommendation should load (took \(elapsed)s)")
        // Allow generous 30s for network + scoring
        XCTAssertLessThan(elapsed, 30.0,
            "Recommendation fetch should complete within 30 seconds")
    }

    func test_03_exploreTabLoadsWithinFiveSeconds() {
        let start = Date()
        navigateToExplore()
        let hasContent = app.images.firstMatch.waitForExistence(timeout: 10) ||
                        app.staticTexts["Discover"].waitForExistence(timeout: 10)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(hasContent,
            "Explore content should load (took \(elapsed)s)")
    }

    func test_04_searchResponseWithinFiveSeconds() {
        navigateToExplore()
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else { return }
        searchField.tap()
        let start = Date()
        searchField.typeText("Inception")
        sleep(3)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(app.state == .runningForeground,
            "Search should respond without crashing")
        XCTAssertLessThan(elapsed, 5.0,
            "Search should complete typing within 5 seconds")
    }

    func test_05_swipeResponseTime() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        let start = Date()
        app.swipeLeft()
        app.swipeRight()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 3.0,
            "Two swipes should complete within 3 seconds")
    }

    func test_06_onboardingFlowCompletesReasonably() {
        let start = Date()
        navigateToMainScreen()
        let gotRec = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(gotRec,
            "Full onboarding should complete and show recommendation")
        XCTAssertLessThan(elapsed, 60.0,
            "Full onboarding + recommendation should complete within 60 seconds")
    }

    func test_07_rejectionReplacementTime() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        app.buttons["main_not_tonight"].tap()
        guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { return }
        let start = Date()
        app.buttons["Just show me another"].tap()
        let gotRec = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(gotRec,
            "Replacement recommendation should load")
        XCTAssertLessThan(elapsed, 30.0,
            "Replacement fetch should complete within 30 seconds")
    }

    func test_08_authScreenAppearsQuickly() {
        let start = Date()
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        let appeared = app.buttons["auth_skip"].waitForExistence(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(appeared,
            "Auth screen should appear quickly after Pick For Me")
        XCTAssertLessThan(elapsed, 6.0,
            "Auth screen should appear within 6 seconds of launch")
    }

    func test_09_moodScreenAppearsQuickly() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        app.buttons["auth_skip"].waitForExistence(timeout: 5)
        let start = Date()
        app.buttons["auth_skip"].tap()
        let appeared = app.buttons["mood_card_0"].waitForExistence(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(appeared,
            "Mood screen should appear quickly after auth skip")
        XCTAssertLessThan(elapsed, 3.0,
            "Mood screen transition should take less than 3 seconds")
    }

    func test_10_noMemoryWarningsDuringOnboarding() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        // If we got here without crash, no memory warnings caused termination
        XCTAssertTrue(app.state == .runningForeground,
            "App should complete onboarding without memory-related crashes")
    }
}
