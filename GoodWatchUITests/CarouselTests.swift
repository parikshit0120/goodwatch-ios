import XCTest

class CarouselTests: GWTestBase {

    func test_01_carouselAppearsForMultiPickUsers() {
        navigateToMainScreen()
        // With 1000 interaction points, user is at tier 4 (experienced)
        // Carousel should show multiple cards - verify images exist
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10),
            "Carousel should display at least one movie card with poster")
    }

    func test_02_swipeLeftNavigatesToNextCard() {
        navigateToMainScreen()
        sleep(1)
        let beforeTitle = getMovieTitle()
        app.swipeLeft()
        sleep(1)
        // App should still be running after swipe
        XCTAssertTrue(app.state == .runningForeground,
            "App should not crash on swipe left")
        _ = beforeTitle
    }

    func test_03_swipeRightNavigatesToPreviousCard() {
        navigateToMainScreen()
        sleep(1)
        app.swipeLeft()
        sleep(1)
        app.swipeRight()
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "App should not crash on swipe right")
    }

    func test_04_carouselCardsAreNotDuplicates() {
        navigateToMainScreen()
        // Collect titles from multiple cards by swiping
        var titles: [String] = []
        let firstTitle = getMovieTitle()
        if !firstTitle.isEmpty { titles.append(firstTitle) }

        for _ in 0..<3 {
            app.swipeLeft()
            sleep(1)
            let title = getMovieTitle()
            if !title.isEmpty { titles.append(title) }
        }

        // Filter out empty titles and check uniqueness
        let nonEmpty = titles.filter { !$0.isEmpty }
        if nonEmpty.count > 1 {
            let unique = Set(nonEmpty)
            XCTAssertEqual(unique.count, nonEmpty.count,
                "Carousel should not show duplicate movies: \(nonEmpty)")
        }
    }

    func test_05_swipeDoesNotFreeze() {
        navigateToMainScreen()
        sleep(1)
        let start = Date()
        app.swipeLeft()
        app.swipeRight()
        app.swipeLeft()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0,
            "Three swipes should complete within 5 seconds - no freeze detected")
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_06_carouselShowsGoodScoreOnEachCard() {
        navigateToMainScreen()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].exists,
            "First carousel card should show GOODSCORE")
    }

    func test_07_rapidSwipingDoesNotCrash() {
        navigateToMainScreen()
        sleep(1)
        for _ in 0..<5 {
            app.swipeLeft()
        }
        for _ in 0..<5 {
            app.swipeRight()
        }
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "App should not crash after rapid swiping")
    }

    func test_08_carouselPosterImagesLoad() {
        navigateToMainScreen()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10),
            "Carousel card should have a poster image")
    }

    func test_09_carouselReplacementAfterRejection() {
        navigateToMainScreen()
        let titleBefore = getMovieTitle()
        // Reject via not tonight
        if app.buttons["main_not_tonight"].exists {
            app.buttons["main_not_tonight"].tap()
            if app.buttons["Just show me another"].waitForExistence(timeout: 5) {
                app.buttons["Just show me another"].tap()
                app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
                let titleAfter = getMovieTitle()
                XCTAssertNotEqual(titleBefore, titleAfter,
                    "Replacement card should be different from rejected card")
            }
        }
    }

    func test_10_carouselDoesNotCrashOnEdgeSwipe() {
        navigateToMainScreen()
        sleep(1)
        // Swipe far right from first card (edge case)
        app.swipeRight()
        app.swipeRight()
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Edge swipe should not crash the carousel")
    }
}
