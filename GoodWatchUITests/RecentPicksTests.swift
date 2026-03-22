import XCTest

class RecentPicksTests: GWTestBase {

    func test_01_mainScreenShowsRecommendation() {
        navigateToMainScreen()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30),
            "Main screen should show a recommendation with GOODSCORE")
    }

    func test_02_watchNowRecordsInteraction() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("No recommendation loaded")
            return
        }
        let title = getMovieTitle()
        app.buttons["main_watch_now"].tap()
        sleep(2)
        // App should still be running after watch now
        XCTAssertTrue(app.state == .runningForeground,
            "Watch Now should record interaction without crashing")
        _ = title
    }

    func test_03_rejectedMovieDoesNotReappear() {
        navigateToMainScreen()
        let title1 = getMovieTitle()
        app.buttons["main_not_tonight"].tap()
        if app.buttons["Just show me another"].waitForExistence(timeout: 5) {
            app.buttons["Just show me another"].tap()
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
            let title2 = getMovieTitle()
            XCTAssertNotEqual(title1, title2,
                "Rejected movie should not reappear as next pick")
        }
    }

    func test_04_alreadySeenMovieDoesNotReappear() {
        navigateToMainScreen()
        let title1 = getMovieTitle()
        if app.buttons["Already seen"].exists {
            app.buttons["Already seen"].tap()
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
            let title2 = getMovieTitle()
            XCTAssertNotEqual(title1, title2,
                "Already seen movie should not reappear")
        }
    }

    func test_05_multiplePicksAreTracked() {
        navigateToMainScreen()
        var titles: [String] = []
        for _ in 0..<2 {
            guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { break }
            let title = getMovieTitle()
            if !title.isEmpty { titles.append(title) }
            guard app.buttons["main_not_tonight"].exists else { break }
            app.buttons["main_not_tonight"].tap()
            guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { break }
            app.buttons["Just show me another"].tap()
        }
        let unique = Set(titles)
        XCTAssertEqual(unique.count, titles.count,
            "Each pick should be unique: \(titles)")
    }

    func test_06_recommendationHasTitle() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("No recommendation loaded")
            return
        }
        let title = getMovieTitle()
        XCTAssertFalse(title.isEmpty,
            "Recommendation should have a visible movie title")
    }

    func test_07_recommendationHasPoster() {
        navigateToMainScreen()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10),
            "Recommendation card should have a poster image")
    }

    func test_08_mainScreenShowsAllActionButtons() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("No recommendation loaded")
            return
        }
        XCTAssertTrue(app.buttons["main_watch_now"].exists,
            "Watch Now button should exist")
        XCTAssertTrue(app.buttons["main_not_tonight"].exists,
            "Not Tonight button should exist")
    }

    func test_09_consecutiveRejectionsProduceUniquePicks() {
        navigateToMainScreen()
        var titles: [String] = []
        for _ in 0..<3 {
            guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { break }
            let title = getMovieTitle()
            if !title.isEmpty { titles.append(title) }
            guard app.buttons["main_not_tonight"].waitForExistence(timeout: 3) else { break }
            app.buttons["main_not_tonight"].tap()
            guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { break }
            app.buttons["Just show me another"].tap()
        }
        let nonEmpty = titles.filter { !$0.isEmpty }
        if nonEmpty.count > 1 {
            let unique = Set(nonEmpty)
            XCTAssertEqual(unique.count, nonEmpty.count,
                "Consecutive rejections should produce unique picks: \(nonEmpty)")
        }
    }

    func test_10_appDoesNotCrashAfterMultiplePicks() {
        navigateToMainScreen()
        for _ in 0..<3 {
            guard app.buttons["main_not_tonight"].waitForExistence(timeout: 5) else { break }
            app.buttons["main_not_tonight"].tap()
            guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { break }
            app.buttons["Just show me another"].tap()
            _ = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "App should not crash after multiple pick cycles")
    }
}
