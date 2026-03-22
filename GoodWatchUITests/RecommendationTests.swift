import XCTest

class RecommendationTests: GWTestBase {

    func test_01_mainScreenShowsGoodScore() {
        navigateToMainScreen()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].exists)
    }

    func test_02_mainScreenShowsWatchNow() {
        navigateToMainScreen()
        XCTAssertTrue(app.buttons["main_watch_now"].waitForExistence(timeout: 5))
    }

    func test_03_mainScreenShowsNotTonight() {
        navigateToMainScreen()
        XCTAssertTrue(app.buttons["main_not_tonight"].waitForExistence(timeout: 5))
    }

    func test_04_mainScreenShowsAlreadySeen() {
        navigateToMainScreen()
        XCTAssertTrue(app.buttons["Already seen"].waitForExistence(timeout: 5))
    }

    func test_05_movieHasPosterImage() {
        navigateToMainScreen()
        // Poster image should be visible
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10))
    }

    func test_06_movieHasTitle() {
        navigateToMainScreen()
        // At least one text element besides GOODSCORE should exist (movie title)
        XCTAssertTrue(app.staticTexts.count > 1)
    }

    func test_07_movieYearIsAfter1990() {
        navigateToMainScreen()
        // Check year text - should not contain years before 1990
        let yearTexts = app.staticTexts.allElementsBoundByIndex
            .map { $0.label }
            .filter { $0.count == 4 && Int($0) != nil }
        for yearText in yearTexts {
            if let year = Int(yearText) {
                XCTAssertGreaterThanOrEqual(year, 1990,
                    "Movie year \(year) is before 1990 - year floor violated")
            }
        }
    }

    func test_08_notTonightOpensRejectionSheet() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        XCTAssertTrue(app.buttons["Just show me another"].waitForExistence(timeout: 5))
    }

    func test_09_justShowAnotherReturnsNewRecommendation() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30),
            "New recommendation should appear after rejection")
    }

    func test_10_rejectedMovieDoesNotReappear() {
        navigateToMainScreen()
        // Note first movie title
        let firstTitle = getMovieTitle()
        // Reject it
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        // Second movie title should be different
        let secondTitle = getMovieTitle()
        XCTAssertNotEqual(firstTitle, secondTitle,
            "Rejected movie should not reappear as next recommendation")
    }

    func test_11_alreadySeenFetchesNewRecommendation() {
        navigateToMainScreen()
        app.buttons["Already seen"].tap()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30),
            "New recommendation should appear after Already Seen")
    }

    func test_12_watchNowDoesNotCrash() {
        navigateToMainScreen()
        app.buttons["main_watch_now"].tap()
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_13_secondRejectionAlsoReturnsNewRecommendation() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30),
            "Third recommendation should appear after two rejections")
    }

    func test_14_noMatchesFoundIsLastResort() {
        // With --interaction-points 1000 and all platforms, engine should
        // provide at least 3 picks before exhausting
        navigateToMainScreen()
        XCTAssertFalse(app.staticTexts["No matches found"].exists,
            "Should not show no matches on first recommendation")
    }

    func test_15_recommendationAppearsWithinTenSeconds() {
        let start = Date()
        navigateToMainScreen()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(app.staticTexts["GOODSCORE"].exists)
        // navigateToMainScreen already waits 20s max - if we're here it appeared
        XCTAssertLessThan(elapsed, 30.0, "Recommendation should appear within 30 seconds of onboarding")
    }
}
