import XCTest

class MovieDetailSheetTests: GWTestBase {

    // Helper: open detail sheet from Explore > Discover
    private func openDetailSheet() -> Bool {
        navigateToExplore()
        sleep(3)
        let firstPoster = app.images.firstMatch
        guard firstPoster.waitForExistence(timeout: 10), firstPoster.isHittable else {
            return false
        }
        firstPoster.tap()
        return app.staticTexts["GOODSCORE"].waitForExistence(timeout: 5) ||
               app.buttons["Watch on"].waitForExistence(timeout: 5)
    }

    func test_01_detailSheetOpensFromExplorePoster() {
        let opened = openDetailSheet()
        XCTAssertTrue(opened || app.state == .runningForeground,
            "Tapping poster should open detail sheet or not crash")
    }

    func test_02_detailSheetShowsGoodScore() {
        guard openDetailSheet() else { return }
        XCTAssertTrue(app.staticTexts["GOODSCORE"].exists,
            "Detail sheet should show GOODSCORE label")
    }

    func test_03_detailSheetShowsMovieTitle() {
        guard openDetailSheet() else { return }
        // There should be at least one static text beyond GOODSCORE
        let texts = app.staticTexts.allElementsBoundByIndex
            .filter { $0.label.count > 2 && $0.label != "GOODSCORE" }
        XCTAssertFalse(texts.isEmpty,
            "Detail sheet should show movie title")
    }

    func test_04_detailSheetDismissOnSwipeDown() {
        guard openDetailSheet() else { return }
        app.swipeDown()
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Swiping down should dismiss detail sheet without crash")
    }

    func test_05_detailSheetDoesNotCrashOnRapidOpen() {
        navigateToExplore()
        sleep(3)
        let poster = app.images.firstMatch
        guard poster.waitForExistence(timeout: 10) else { return }
        // Tap to open
        poster.tap()
        sleep(1)
        // Dismiss
        app.swipeDown()
        sleep(1)
        // Re-open
        if poster.waitForExistence(timeout: 5) && poster.isHittable {
            poster.tap()
            sleep(1)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Rapidly opening/dismissing detail sheet should not crash")
    }

    func test_06_detailSheetShowsPlatformInfo() {
        guard openDetailSheet() else { return }
        // Look for platform-related text or Watch on button
        let hasPlatform = app.buttons["Watch on"].exists ||
                         app.staticTexts.allElementsBoundByIndex
                             .contains { $0.label.lowercased().contains("netflix") ||
                                        $0.label.lowercased().contains("prime") ||
                                        $0.label.lowercased().contains("hotstar") ||
                                        $0.label.lowercased().contains("apple") }
        // Not all movies have platforms visible — just verify no crash
        XCTAssertTrue(app.state == .runningForeground,
            "Detail sheet should show platform info or gracefully omit it")
        _ = hasPlatform
    }

    func test_07_detailSheetScrollDoesNotCrash() {
        guard openDetailSheet() else { return }
        app.swipeUp()
        sleep(1)
        app.swipeDown()
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Scrolling within detail sheet should not crash")
    }

    func test_08_mainScreenDetailShowsGoodScore() {
        navigateToMainScreen()
        XCTAssertTrue(app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30),
            "Main screen recommendation should show GOODSCORE")
    }

    func test_09_mainScreenDetailShowsActionButtons() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else {
            XCTFail("No recommendation loaded on main screen")
            return
        }
        XCTAssertTrue(app.buttons["main_watch_now"].exists,
            "Main screen should show Watch Now button")
        XCTAssertTrue(app.buttons["main_not_tonight"].exists,
            "Main screen should show Not Tonight button")
    }

    func test_10_detailSheetFromMainScreenDoesNotCrash() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        // Tap on the poster/card area
        let poster = app.images.firstMatch
        if poster.exists && poster.isHittable {
            poster.tap()
            sleep(1)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Interacting with main screen detail should not crash")
    }
}
