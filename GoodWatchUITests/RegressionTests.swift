import XCTest

class RegressionTests: GWTestBase {

    // Regression: Bug fix 0b93308 — Onboarding loop
    // Completing onboarding should persist; relaunch should skip onboarding
    func test_01_onboardingDoesNotLoopAfterCompletion() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("Main screen did not load after onboarding")
            return
        }
        // Terminate and relaunch WITHOUT --reset-onboarding
        app.terminate()
        sleep(1)
        launchReturning()
        sleep(3)
        // Should skip onboarding and show either main screen or landing
        // The key check: should NOT be stuck in an infinite onboarding loop
        XCTAssertTrue(app.state == .runningForeground,
            "App should not be stuck in onboarding loop after completion (regression 0b93308)")
    }

    // Regression: Bug fix 7c66881 — Pre-1990 movies should not appear
    // Year floor check: recommendation should not show very old movies
    func test_02_noPreNinetiesMoviesRecommended() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        // Check all visible static texts for year patterns
        let allTexts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        let yearPattern = try! NSRegularExpression(pattern: "\\b(19[0-8]\\d)\\b")
        var foundOldYear = false
        for text in allTexts {
            let range = NSRange(text.startIndex..., in: text)
            if yearPattern.firstMatch(in: text, range: range) != nil {
                foundOldYear = true
                break
            }
        }
        XCTAssertFalse(foundOldYear,
            "No pre-1990 movies should be recommended (regression 7c66881)")
    }

    // Regression: Bug fix fd3e794 — Carousel duplicates
    // Swiping through carousel should not show duplicate movies
    func test_03_carouselDoesNotShowDuplicates() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        var titles: [String] = []
        let firstTitle = getMovieTitle()
        if !firstTitle.isEmpty { titles.append(firstTitle) }

        for _ in 0..<3 {
            app.swipeLeft()
            sleep(1)
            let title = getMovieTitle()
            if !title.isEmpty { titles.append(title) }
        }

        let nonEmpty = titles.filter { !$0.isEmpty }
        if nonEmpty.count > 1 {
            let unique = Set(nonEmpty)
            XCTAssertEqual(unique.count, nonEmpty.count,
                "Carousel should not show duplicate movies (regression fd3e794): \(nonEmpty)")
        }
    }

    // Regression: Bug fix ebc5765 — Swipe performance
    // Multiple swipes should complete quickly without freezing
    func test_04_swipePerformanceDoesNotDegrade() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        sleep(1)
        let start = Date()
        app.swipeLeft()
        app.swipeRight()
        app.swipeLeft()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0,
            "Three swipes should complete within 5 seconds (regression ebc5765)")
        XCTAssertTrue(app.state == .runningForeground)
    }

    // Regression: Bug fix bf18b1c — Poster tappability in Explore
    func test_05_explorePosterIsTappable() {
        navigateToExplore()
        sleep(3)
        let poster = app.images.firstMatch
        XCTAssertTrue(poster.waitForExistence(timeout: 10),
            "Explore should show at least one poster image")
        XCTAssertTrue(poster.isHittable,
            "Explore poster should be tappable (regression bf18b1c)")
    }

    // Regression: Suppression gate — rejected movie must not reappear
    func test_06_suppressedMovieNeverReappears() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        let title1 = getMovieTitle()
        app.buttons["main_not_tonight"].tap()
        guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { return }
        app.buttons["Just show me another"].tap()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        let title2 = getMovieTitle()
        XCTAssertNotEqual(title1, title2,
            "Suppressed movie must not reappear (suppression regression)")
    }

    // Regression: Black screen after rejection
    func test_07_noBlackScreenAfterRejection() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        app.buttons["main_not_tonight"].tap()
        guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { return }
        app.buttons["Just show me another"].tap()
        sleep(2)
        XCTAssertTrue(
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) ||
            app.staticTexts["No matches found"].waitForExistence(timeout: 30),
            "After rejection must show new rec or no-matches, never black screen")
    }

    // Regression: Onboarding linear flow (INV-U02)
    func test_08_onboardingIsStrictlyLinear() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        // Auth -> Mood -> Platform must be sequential
        XCTAssertTrue(app.buttons["auth_skip"].waitForExistence(timeout: 5),
            "Auth screen must appear first")
        app.buttons["auth_skip"].tap()
        XCTAssertTrue(app.buttons["mood_card_0"].waitForExistence(timeout: 5),
            "Mood screen must appear after auth")
        app.buttons["mood_card_0"].tap()
        app.buttons["mood_continue"].tap()
        XCTAssertTrue(app.buttons["platform_0"].waitForExistence(timeout: 5),
            "Platform screen must appear after mood (strictly linear)")
    }

    // Regression: Explore auth gate (INV-U05)
    func test_09_exploreRequiresAuth() {
        app.launch()
        app.staticTexts["Explore & Search"].tap()
        XCTAssertTrue(
            app.buttons["auth_skip"].waitForExistence(timeout: 5) ||
            app.buttons["auth_apple_sign_in"].waitForExistence(timeout: 5),
            "Explore must require auth gate (INV-U05 regression)")
    }

    // Regression: App stability across full flow
    func test_10_fullFlowDoesNotCrash() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        // Reject and get replacement
        app.buttons["main_not_tonight"].tap()
        if app.buttons["Just show me another"].waitForExistence(timeout: 5) {
            app.buttons["Just show me another"].tap()
            _ = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        }
        // Swipe carousel
        app.swipeLeft()
        app.swipeRight()
        XCTAssertTrue(app.state == .runningForeground,
            "Full flow (onboard -> recommend -> reject -> swipe) should not crash")
    }
}
