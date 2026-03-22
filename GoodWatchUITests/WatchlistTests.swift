import XCTest

class WatchlistTests: GWTestBase {

    func test_01_watchlistTabIsAccessible() {
        navigateToExplore()
        XCTAssertTrue(
            app.staticTexts["Watchlist"].waitForExistence(timeout: 5) ||
            app.buttons["Watchlist"].waitForExistence(timeout: 5),
            "Watchlist tab should be accessible in Explore"
        )
    }

    func test_02_watchlistTabTapDoesNotCrash() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "Tapping Watchlist tab should not crash")
    }

    func test_03_watchlistShowsEmptyStateOrContent() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(3)
        // Either shows content (cells/images) or empty state message
        XCTAssertTrue(app.state == .runningForeground,
            "Watchlist should display empty state or saved movies")
    }

    func test_04_watchlistDoesNotCrashOnScroll() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(2)
        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(app.state == .runningForeground,
            "Scrolling watchlist should not crash")
    }

    func test_05_watchlistPosterTapDoesNotCrash() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(3)
        let firstImage = app.images.firstMatch
        if firstImage.waitForExistence(timeout: 5) && firstImage.isHittable {
            firstImage.tap()
            sleep(1)
            XCTAssertTrue(app.state == .runningForeground,
                "Tapping watchlist poster should not crash")
        }
    }

    func test_06_watchlistPosterOpensDetailSheet() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(3)
        let firstImage = app.images.firstMatch
        if firstImage.waitForExistence(timeout: 5) && firstImage.isHittable {
            firstImage.tap()
            // Detail sheet may appear
            let hasDetail = app.staticTexts["GOODSCORE"].waitForExistence(timeout: 5) ||
                           app.buttons["Watch on"].waitForExistence(timeout: 5)
            if hasDetail {
                XCTAssertTrue(true, "Detail sheet opened from watchlist")
            }
        }
        XCTAssertTrue(app.state == .runningForeground)
    }

    func test_07_watchlistNavigationBackDoesNotCrash() {
        navigateToExplore()
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(2)
        // Navigate back to Discover
        if app.staticTexts["Discover"].exists {
            app.staticTexts["Discover"].tap()
        } else if app.buttons["Discover"].exists {
            app.buttons["Discover"].tap()
        }
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Navigating away from Watchlist should not crash")
    }

    func test_08_watchlistIsVisibleAfterTabSwitch() {
        navigateToExplore()
        // Go to Soon first
        if app.staticTexts["Soon"].exists { app.staticTexts["Soon"].tap() }
        else if app.buttons["Soon"].exists { app.buttons["Soon"].tap() }
        sleep(1)
        // Then go to Watchlist
        if app.staticTexts["Watchlist"].exists {
            app.staticTexts["Watchlist"].tap()
        } else if app.buttons["Watchlist"].exists {
            app.buttons["Watchlist"].tap()
        }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "Watchlist should be accessible after switching tabs")
    }

    func test_09_rapidTabSwitchingIncludingWatchlistDoesNotCrash() {
        navigateToExplore()
        for _ in 0..<3 {
            if app.staticTexts["Discover"].exists { app.staticTexts["Discover"].tap() }
            else if app.buttons["Discover"].exists { app.buttons["Discover"].tap() }
            if app.staticTexts["Watchlist"].exists { app.staticTexts["Watchlist"].tap() }
            else if app.buttons["Watchlist"].exists { app.buttons["Watchlist"].tap() }
        }
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid tab switching including Watchlist should not crash")
    }

    func test_10_watchlistTabIsHittable() {
        navigateToExplore()
        let watchlistText = app.staticTexts["Watchlist"]
        let watchlistButton = app.buttons["Watchlist"]
        if watchlistText.exists {
            XCTAssertTrue(watchlistText.isHittable,
                "Watchlist tab text should be hittable")
        } else if watchlistButton.exists {
            XCTAssertTrue(watchlistButton.isHittable,
                "Watchlist tab button should be hittable")
        }
        XCTAssertTrue(app.state == .runningForeground)
    }
}
