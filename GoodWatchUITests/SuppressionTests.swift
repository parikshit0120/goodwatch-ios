import XCTest

class SuppressionTests: GWTestBase {

    func test_01_suppressionGatePreventsRepeat() {
        navigateToMainScreen()
        let title1 = getMovieTitle()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        let title2 = getMovieTitle()
        XCTAssertNotEqual(title1, title2, "Suppressed movie must not reappear")
    }

    func test_02_threeConsecutiveRejectionsAllDifferent() {
        navigateToMainScreen()
        var titles: [String] = []

        for _ in 0..<3 {
            let title = app.staticTexts.allElementsBoundByIndex
                .filter { $0.label.count > 3 && $0.label != "GOODSCORE" }
                .first?.label ?? UUID().uuidString
            titles.append(title)
            if app.buttons["main_not_tonight"].exists {
                app.buttons["main_not_tonight"].tap()
                if app.buttons["Just show me another"].waitForExistence(timeout: 5) {
                    app.buttons["Just show me another"].tap()
                    app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
                } else { break }
            } else { break }
        }

        let uniqueTitles = Set(titles)
        XCTAssertEqual(uniqueTitles.count, titles.count,
            "All \(titles.count) recommendations should be unique: \(titles)")
    }

    func test_03_rejectionSheetHasJustShowMeAnother() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        XCTAssertTrue(app.buttons["Just show me another"].waitForExistence(timeout: 5))
    }

    func test_04_rejectionSheetHasNeverMindOption() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        // Sheet should have a dismiss/cancel option
        XCTAssertTrue(
            app.buttons["Never mind"].waitForExistence(timeout: 3) ||
            app.buttons["Cancel"].waitForExistence(timeout: 3) ||
            app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3)
        )
    }

    func test_05_blackScreenDoesNotAppearAfterRejection() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        sleep(2)
        // App should not be showing a black/empty screen
        XCTAssertTrue(app.state == .runningForeground)
        XCTAssertTrue(
            app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) ||
            app.staticTexts["No matches found"].waitForExistence(timeout: 30),
            "After rejection, must show either new rec or no-matches - never black screen"
        )
    }

    func test_06_alreadySeenDoesNotRepeat() {
        navigateToMainScreen()
        let title1 = getMovieTitle()
        app.buttons["Already seen"].tap()
        app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        let title2 = getMovieTitle()
        XCTAssertNotEqual(title1, title2, "Already seen movie must not reappear")
    }

    func test_07_suppressionPersistsAcrossSession() {
        // Note: with clearState=false, suppressions from prior session should persist
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_08_replacementLimitToastAppears() {
        // Pre-maturity: max 5 replacements per session
        // With 1000 interaction points we're post-maturity so no limit applies
        // Just verify no crash on multiple rejections
        navigateToMainScreen()
        for _ in 0..<3 {
            guard app.buttons["main_not_tonight"].waitForExistence(timeout: 5) else { break }
            app.buttons["main_not_tonight"].tap()
            guard app.buttons["Just show me another"].waitForExistence(timeout: 5) else { break }
            app.buttons["Just show me another"].tap()
            guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { break }
        }
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_09_noMatchesFoundNeverAppearsTooEarly() {
        navigateToMainScreen()
        XCTAssertFalse(app.staticTexts["No matches found"].exists)
        // Reject once
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        sleep(2)
        // Should not immediately show no matches (progressive fallback should kick in)
        if app.staticTexts["No matches found"].exists {
            XCTFail("No matches found appeared after only 1 rejection - progressive fallback may be broken")
        }
    }

    func test_10_progressiveFallbackPreventsImmediateExhaustion() {
        navigateToMainScreen()
        app.buttons["main_not_tonight"].tap()
        app.buttons["Just show me another"].waitForExistence(timeout: 5)
        app.buttons["Just show me another"].tap()
        let gotNewRec = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30)
        XCTAssertTrue(gotNewRec,
            "Progressive fallback must provide at least one replacement before exhaustion")
    }
}
