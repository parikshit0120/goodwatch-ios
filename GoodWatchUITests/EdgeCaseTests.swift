import XCTest

class EdgeCaseTests: GWTestBase {

    func test_01_rapidLandingButtonTapping() {
        launchFresh()
        guard app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5) else {
            XCTFail("Landing screen did not appear")
            return
        }
        // Rapidly tap Pick For Me multiple times
        for _ in 0..<5 {
            app.buttons["landing_pick_for_me"].tap()
        }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid landing button tapping should not crash the app")
    }

    func test_02_backgroundAndForegroundCycle() {
        launchFresh()
        app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5)
        // Press home (background)
        XCUIDevice.shared.press(.home)
        sleep(2)
        // Bring back to foreground
        app.activate()
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "App should survive background/foreground cycle")
    }

    func test_03_doubleTapOnMoodCard() {
        navigateToMoodScreen()
        if app.buttons["mood_card_0"].exists {
            app.buttons["mood_card_0"].doubleTap()
            sleep(1)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Double-tapping mood card should not crash")
    }

    func test_04_rapidPlatformToggling() {
        navigateToPlatformScreen()
        for _ in 0..<5 {
            if app.buttons["platform_0"].exists {
                app.buttons["platform_0"].tap()
            }
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid platform toggling should not crash")
    }

    func test_05_swipeOnLandingScreen() {
        launchFresh()
        app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5)
        app.swipeLeft()
        app.swipeRight()
        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(app.state == .runningForeground,
            "Swiping on landing screen should not crash")
    }

    func test_06_launchTerminateRelaunchCycle() {
        launchFresh()
        app.buttons["landing_pick_for_me"].waitForExistence(timeout: 5)
        app.terminate()
        sleep(1)
        app.launch()
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "App should survive terminate and relaunch")
    }

    func test_07_rapidNotTonightTapping() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        // Rapidly tap not tonight multiple times
        for _ in 0..<3 {
            if app.buttons["main_not_tonight"].exists {
                app.buttons["main_not_tonight"].tap()
            }
        }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid Not Tonight tapping should not crash")
    }

    func test_08_orientationChangeOnMainScreen() {
        navigateToMainScreen()
        guard app.staticTexts["GOODSCORE"].waitForExistence(timeout: 30) else { return }
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Orientation change should not crash the app")
    }

    func test_09_rapidAuthSkipDoubleTap() {
        launchFresh()
        app.buttons["landing_pick_for_me"].tap()
        if app.buttons["auth_skip"].waitForExistence(timeout: 5) {
            app.buttons["auth_skip"].doubleTap()
            sleep(2)
        }
        XCTAssertTrue(app.state == .runningForeground,
            "Double-tapping auth skip should not crash")
    }

    func test_10_rapidExploreTabSwitching() {
        navigateToExplore()
        for _ in 0..<5 {
            if app.staticTexts["Discover"].exists { app.staticTexts["Discover"].tap() }
            else if app.buttons["Discover"].exists { app.buttons["Discover"].tap() }
            if app.staticTexts["Soon"].exists { app.staticTexts["Soon"].tap() }
            else if app.buttons["Soon"].exists { app.buttons["Soon"].tap() }
        }
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground,
            "Rapid Explore tab switching should not crash")
    }
}
