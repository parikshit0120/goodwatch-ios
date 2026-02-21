import XCTest

// ============================================
// SCREENSHOT TESTS — GoodWatch v1.3
// ============================================
// Captures 12 screenshots for App Store submission.
// Uses launch arguments to control app state:
//   --screenshot-mode: suppresses analytics/diagnostics
//   --interaction-points N: sets carousel tier
//   --skip-loading-delay: skips ConfidenceMoment animation
//   --reset-onboarding: clears all onboarding state
//
// Saves PNGs to /tmp/goodwatch_screenshots/
// Run: xcodebuild test -scheme GoodWatch -testPlan Screenshots
//   or: Xcode -> Product -> Test (select GWScreenshotTests)
// ============================================

final class GWScreenshotTests: XCTestCase {

    var app: XCUIApplication!
    let screenshotDir = "/tmp/goodwatch_screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "0"  // Default: 5-card carousel
        ]

        // Create screenshot directory
        try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func saveScreenshot(_ name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to /tmp for easy access
        let data = screenshot.pngRepresentation
        let path = "\(screenshotDir)/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private func waitForElement(_ identifier: String, timeout: TimeInterval = 10) -> XCUIElement {
        let element = app.buttons[identifier].firstMatch
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            // Fallback: try as a static text or other element type
            let staticText = app.staticTexts[identifier].firstMatch
            if staticText.waitForExistence(timeout: 2) {
                return staticText
            }
            // Try otherElements
            let other = app.otherElements[identifier].firstMatch
            if other.waitForExistence(timeout: 2) {
                return other
            }
        }
        return element
    }

    /// Navigate through onboarding by tapping Skip auth, first mood, all platforms, first duration
    private func navigateThroughOnboarding() {
        // Landing screen -> Pick for me
        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) {
            pickForMe.tap()
        }

        // Auth screen -> Skip (continue without account)
        let authSkip = waitForElement("auth_skip")
        if authSkip.waitForExistence(timeout: 5) {
            authSkip.tap()
        }

        // Mood selector -> select first mood (Feel-good) + Continue
        let moodCard = app.otherElements["mood_card_0"].firstMatch
        if moodCard.waitForExistence(timeout: 5) {
            moodCard.tap()
        } else {
            // Fallback: tap first mood by text
            let feelGood = app.staticTexts["Feel-good"].firstMatch
            if feelGood.waitForExistence(timeout: 3) {
                feelGood.tap()
            }
        }

        let moodContinue = waitForElement("mood_continue")
        if moodContinue.waitForExistence(timeout: 3) {
            moodContinue.tap()
        }

        // Platform selector -> tap Netflix + English + Continue
        let netflix = app.otherElements["platform_netflix"].firstMatch
        if netflix.waitForExistence(timeout: 5) {
            netflix.tap()
        } else {
            // Fallback: tap "Select all"
            let selectAll = app.buttons["Select all"].firstMatch
            if selectAll.waitForExistence(timeout: 3) {
                selectAll.tap()
            }
        }

        // Select English language
        let english = app.staticTexts["English"].firstMatch
        if english.waitForExistence(timeout: 3) {
            english.tap()
        }

        let platformContinue = waitForElement("platform_continue")
        if platformContinue.waitForExistence(timeout: 3) {
            platformContinue.tap()
        }

        // Duration selector -> select "2-2.5 hours" + Continue
        let durationCard = app.otherElements["duration_card_1"].firstMatch
        if durationCard.waitForExistence(timeout: 5) {
            durationCard.tap()
        } else {
            // Fallback: tap by text
            let fullMovie = app.staticTexts["2-2.5 hours"].firstMatch
            if fullMovie.waitForExistence(timeout: 3) {
                fullMovie.tap()
            }
        }

        let durationContinue = waitForElement("duration_continue")
        if durationContinue.waitForExistence(timeout: 3) {
            durationContinue.tap()
        }
    }

    // MARK: - Screenshot Tests

    /// 1. Landing screen with poster grid
    func test01_LandingScreen() throws {
        app.launch()

        // Wait for landing to load (posters take a moment)
        let pickForMe = waitForElement("landing_pick_for_me")
        XCTAssertTrue(pickForMe.waitForExistence(timeout: 10), "Landing screen should show Pick for me button")

        // Wait a bit for poster grid to load
        sleep(3)
        saveScreenshot("01_landing")
    }

    /// 2. Auth screen
    func test02_AuthScreen() throws {
        app.launch()

        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) {
            pickForMe.tap()
        }

        let authSkip = waitForElement("auth_skip")
        XCTAssertTrue(authSkip.waitForExistence(timeout: 5), "Auth screen should show Skip button")

        sleep(1)
        saveScreenshot("02_auth")
    }

    /// 3. Mood selector screen
    func test03_MoodSelector() throws {
        app.launch()

        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) { pickForMe.tap() }

        let authSkip = waitForElement("auth_skip")
        if authSkip.waitForExistence(timeout: 5) { authSkip.tap() }

        let moodCard = app.otherElements["mood_card_0"].firstMatch
        XCTAssertTrue(moodCard.waitForExistence(timeout: 5), "Mood selector should show mood cards")

        sleep(1)
        saveScreenshot("03_mood_selector")
    }

    /// 4. Mood selected state
    func test04_MoodSelected() throws {
        app.launch()

        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) { pickForMe.tap() }

        let authSkip = waitForElement("auth_skip")
        if authSkip.waitForExistence(timeout: 5) { authSkip.tap() }

        let moodCard = app.otherElements["mood_card_0"].firstMatch
        if moodCard.waitForExistence(timeout: 5) { moodCard.tap() }

        sleep(1)
        saveScreenshot("04_mood_selected")
    }

    /// 5. Platform selector screen
    func test05_PlatformSelector() throws {
        app.launch()

        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) { pickForMe.tap() }

        let authSkip = waitForElement("auth_skip")
        if authSkip.waitForExistence(timeout: 5) { authSkip.tap() }

        let moodCard = app.otherElements["mood_card_0"].firstMatch
        if moodCard.waitForExistence(timeout: 5) { moodCard.tap() }

        let moodContinue = waitForElement("mood_continue")
        if moodContinue.waitForExistence(timeout: 3) { moodContinue.tap() }

        let netflix = app.otherElements["platform_netflix"].firstMatch
        XCTAssertTrue(netflix.waitForExistence(timeout: 5), "Platform selector should show Netflix")

        sleep(1)
        saveScreenshot("05_platform_selector")
    }

    /// 6. Duration selector screen
    func test06_DurationSelector() throws {
        app.launch()

        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) { pickForMe.tap() }

        let authSkip = waitForElement("auth_skip")
        if authSkip.waitForExistence(timeout: 5) { authSkip.tap() }

        let moodCard = app.otherElements["mood_card_0"].firstMatch
        if moodCard.waitForExistence(timeout: 5) { moodCard.tap() }

        let moodContinue = waitForElement("mood_continue")
        if moodContinue.waitForExistence(timeout: 3) { moodContinue.tap() }

        let netflix = app.otherElements["platform_netflix"].firstMatch
        if netflix.waitForExistence(timeout: 5) { netflix.tap() }

        let english = app.staticTexts["English"].firstMatch
        if english.waitForExistence(timeout: 3) { english.tap() }

        let platformContinue = waitForElement("platform_continue")
        if platformContinue.waitForExistence(timeout: 3) { platformContinue.tap() }

        let durationCard = app.otherElements["duration_card_0"].firstMatch
        XCTAssertTrue(durationCard.waitForExistence(timeout: 5), "Duration selector should show duration cards")

        sleep(1)
        saveScreenshot("06_duration_selector")
    }

    /// 7. Confidence moment (loading screen)
    func test07_ConfidenceMoment() throws {
        // Don't skip loading delay for this screenshot
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "0"
        ]
        app.launch()

        navigateThroughOnboarding()

        // ConfidenceMoment should appear briefly
        let confidence = app.otherElements["confidence_moment_screen"].firstMatch
        if confidence.waitForExistence(timeout: 5) {
            saveScreenshot("07_confidence_moment")
        } else {
            // It may have already transitioned — capture whatever is on screen
            saveScreenshot("07_confidence_moment")
        }
    }

    /// 8. Main recommendation screen (single pick)
    func test08_MainScreen_SinglePick() throws {
        // Set high interaction points for single-pick mode
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "200"  // Single pick mode
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for recommendation to load
        let watchNow = app.buttons["main_watch_now"].firstMatch
        if watchNow.waitForExistence(timeout: 15) {
            sleep(2)  // Let poster load
            saveScreenshot("08_main_single_pick")
        } else {
            // Recommendation may not have loaded (no network) — capture anyway
            sleep(3)
            saveScreenshot("08_main_single_pick")
        }
    }

    /// 9. Main recommendation screen (carousel with multiple picks)
    func test09_MainScreen_Carousel() throws {
        // Set 0 interaction points for 5-card carousel
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "0"  // 5-card carousel
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for carousel to load
        sleep(5)  // Let multiple posters load
        saveScreenshot("09_main_carousel")
    }

    /// 10. Enjoy screen (after watching)
    func test10_EnjoyScreen() throws {
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "200"  // Single pick for simpler flow
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for recommendation, then tap Watch Now
        let watchNow = app.buttons["main_watch_now"].firstMatch
        if watchNow.waitForExistence(timeout: 15) {
            watchNow.tap()

            // Enjoy screen should appear
            let enjoyText = app.staticTexts["Enjoy!"].firstMatch
            if enjoyText.waitForExistence(timeout: 5) {
                sleep(1)
                saveScreenshot("10_enjoy_screen")
            } else {
                sleep(2)
                saveScreenshot("10_enjoy_screen")
            }
        } else {
            sleep(3)
            saveScreenshot("10_enjoy_screen")
        }
    }

    /// 11. Landing with Explore button
    func test11_LandingWithExplore() throws {
        app.launch()

        let explore = waitForElement("landing_explore")
        if explore.waitForExistence(timeout: 8) {
            sleep(2)
            saveScreenshot("11_landing_explore")
        } else {
            sleep(3)
            saveScreenshot("11_landing_explore")
        }
    }

    /// 12. Update banner (simulated — banner won't actually show unless version mismatch)
    func test12_UpdateBanner() throws {
        app.launch()

        // The update banner only shows when App Store has a newer version.
        // For screenshots, just capture the landing state — the banner
        // will only be visible in production when an update exists.
        let pickForMe = waitForElement("landing_pick_for_me")
        if pickForMe.waitForExistence(timeout: 8) {
            sleep(2)
            saveScreenshot("12_landing_clean")
        }
    }
}
