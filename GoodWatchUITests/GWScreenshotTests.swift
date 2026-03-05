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
//   --force-feature-flag <name>: forces a feature flag to enabled
//
// Saves PNGs to /tmp/goodwatch_screenshots/
// Run: xcodebuild test -scheme GoodWatch -only-testing:GoodWatchUITests
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
            "--interaction-points", "200",   // Default: single pick
            "--force-feature-flag", "progressive_picks"
        ]

        // Create screenshot directory
        try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true
        )

        // Auto-dismiss system dialogs (notification permission, etc.)
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            let dontAllow = alert.buttons["Don\u{2019}t Allow"].firstMatch
            if dontAllow.exists {
                dontAllow.tap()
                return true
            }
            let notNow = alert.buttons["Not Now"].firstMatch
            if notNow.exists {
                notNow.tap()
                return true
            }
            return false
        }
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

    /// Find any element by accessibility identifier, trying multiple element types
    private func findElement(_ identifier: String, timeout: TimeInterval = 10) -> XCUIElement? {
        // Try buttons first (most common tappable element)
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: timeout) {
            return button
        }

        // Try other elements (VStacks, HStacks with identifiers)
        let other = app.otherElements[identifier].firstMatch
        if other.waitForExistence(timeout: 2) {
            return other
        }

        // Try static texts
        let text = app.staticTexts[identifier].firstMatch
        if text.waitForExistence(timeout: 2) {
            return text
        }

        return nil
    }

    /// Tap an element by identifier, with text-based fallback
    private func tapElement(_ identifier: String, fallbackText: String? = nil, timeout: TimeInterval = 8) -> Bool {
        if let element = findElement(identifier, timeout: timeout), element.isHittable {
            element.tap()
            return true
        }

        // Fallback: find by visible text
        if let text = fallbackText {
            // Try as button label first
            let button = app.buttons[text].firstMatch
            if button.waitForExistence(timeout: 3) && button.isHittable {
                button.tap()
                return true
            }
            let staticText = app.staticTexts[text].firstMatch
            if staticText.waitForExistence(timeout: 2) && staticText.isHittable {
                staticText.tap()
                return true
            }
        }

        return false
    }

    /// Wait for a screen transition by checking for a new element
    private func waitForScreen(_ identifier: String, fallbackText: String? = nil, timeout: TimeInterval = 8) -> Bool {
        if let _ = findElement(identifier, timeout: timeout) {
            return true
        }
        if let text = fallbackText {
            return app.staticTexts[text].firstMatch.waitForExistence(timeout: 3)
        }
        return false
    }

    // MARK: - Onboarding Navigation Helpers

    /// Navigate from Landing to Auth screen
    private func goToAuth() {
        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        _ = waitForScreen("auth_skip", fallbackText: "Continue without account", timeout: 8)
        sleep(1)
    }

    /// Navigate from Landing past Auth to Mood screen
    private func goToMood() {
        goToAuth()
        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        _ = waitForScreen("mood_card_0", fallbackText: "What's the vibe?", timeout: 8)
        sleep(1)
    }

    /// Navigate from Landing past Auth+Mood to Platform screen
    private func goToPlatform() {
        goToMood()
        // Select mood
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        _ = tapElement("mood_continue", fallbackText: "Continue", timeout: 3)
        _ = waitForScreen("platform_netflix", fallbackText: "Which platforms do you have?", timeout: 8)
        sleep(1)
    }

    /// Navigate from Platform to Language Priority screen
    private func goToLanguagePriority() {
        goToPlatform()
        // Select platforms
        let selectAll = app.buttons["Select all"].firstMatch
        if selectAll.waitForExistence(timeout: 3) && selectAll.isHittable {
            selectAll.tap()
        } else {
            _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        }
        sleep(1)
        _ = tapElement("platform_continue", fallbackText: "Continue", timeout: 3)
        // Wait for Language Priority screen
        _ = waitForScreen("language_lock", fallbackText: "What do you watch in?", timeout: 8)
        sleep(1)
    }

    /// Navigate from Landing to Duration screen
    private func goToDuration() {
        goToLanguagePriority()
        // Select English on Language Priority
        let englishBtn = app.buttons["English"].firstMatch
        if englishBtn.waitForExistence(timeout: 3) && englishBtn.isHittable {
            englishBtn.tap()
        }
        sleep(1)
        // Tap Lock Priority to proceed to Duration
        _ = tapElement("language_lock", fallbackText: "Lock Priority", timeout: 3)
        _ = waitForScreen("duration_card_0", fallbackText: "How long", timeout: 8)
        sleep(1)
    }

    /// Navigate all the way through onboarding to recommendation screen
    private func navigateThroughOnboarding() {
        goToDuration()
        // Select duration + continue
        if !tapElement("duration_card_1", timeout: 5) {
            let fullMovie = app.buttons["2-2.5 hours"].firstMatch
            if fullMovie.waitForExistence(timeout: 3) && fullMovie.isHittable {
                fullMovie.tap()
            } else {
                let fullMovieText = app.staticTexts["2-2.5 hours"].firstMatch
                if fullMovieText.waitForExistence(timeout: 3) && fullMovieText.isHittable {
                    fullMovieText.tap()
                }
            }
        }
        sleep(1)
        _ = tapElement("duration_continue", fallbackText: "Continue", timeout: 3)
        sleep(2)
    }

    // MARK: - Screenshot Tests

    /// 1. Landing screen with poster grid
    func test01_LandingScreen() throws {
        app.launch()
        _ = waitForScreen("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(3)  // Let poster grid load
        saveScreenshot("01_landing")
    }

    /// 2. Auth screen (Apple, Google, Facebook sign-in + Skip)
    func test02_AuthScreen() throws {
        app.launch()
        goToAuth()
        sleep(1)
        saveScreenshot("02_auth")
    }

    /// 3. Mood selector screen (no selection -- gray Continue)
    func test03_MoodSelector() throws {
        app.launch()
        goToMood()
        saveScreenshot("03_mood_selector")
    }

    /// 4. Mood selected state (Feel-good highlighted -- gold Continue)
    func test04_MoodSelected() throws {
        app.launch()
        goToMood()
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        saveScreenshot("04_mood_selected")
    }

    /// 5. Platform selector with OTT icons
    func test05_PlatformSelector() throws {
        app.launch()
        goToPlatform()
        // Select Netflix to show gold highlight
        _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        sleep(1)
        saveScreenshot("05_platform_selector")
    }

    /// 6. Language priority screen
    func test06_LanguagePriority() throws {
        app.launch()
        goToLanguagePriority()
        // Select English + Hindi to show ranking
        let englishBtn = app.buttons["English"].firstMatch
        if englishBtn.waitForExistence(timeout: 3) && englishBtn.isHittable {
            englishBtn.tap()
        }
        sleep(1)
        let hindiBtn = app.buttons["Hindi"].firstMatch
        if hindiBtn.waitForExistence(timeout: 3) && hindiBtn.isHittable {
            hindiBtn.tap()
        }
        sleep(1)
        saveScreenshot("06_language_priority")
    }

    /// 7. Duration selector (3 options)
    func test07_DurationSelector() throws {
        app.launch()
        goToDuration()
        saveScreenshot("07_duration_selector")
    }

    /// 8. Duration selected state
    func test08_DurationSelected() throws {
        app.launch()
        goToDuration()
        if !tapElement("duration_card_1", timeout: 5) {
            let fullMovie = app.buttons["2-2.5 hours"].firstMatch
            if fullMovie.waitForExistence(timeout: 3) && fullMovie.isHittable {
                fullMovie.tap()
            }
        }
        sleep(1)
        saveScreenshot("08_duration_selected")
    }

    /// 9. Confidence moment / loading screen
    func test09_ConfidenceMoment() throws {
        // DON'T skip loading delay -- we want to capture the animation
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "200",
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // ConfidenceMoment should appear -- capture immediately
        let confidence = app.otherElements["confidence_moment_screen"].firstMatch
        if confidence.waitForExistence(timeout: 5) {
            saveScreenshot("09_confidence_moment")
        } else {
            saveScreenshot("09_confidence_moment")
        }
    }

    /// 10. Main recommendation screen -- single pick with GoodScore
    func test10_MainScreen_SinglePick() throws {
        // openOTT is suppressed in screenshot-mode, so Netflix won't open
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "200",   // 160+ = single pick
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for main screen elements to appear
        let notTonight = app.buttons["main_not_tonight"].firstMatch
        if notTonight.waitForExistence(timeout: 30) {
            // Tap app to dismiss any system dialogs (notification permission)
            app.tap()
            sleep(2)
            saveScreenshot("10_main_single_pick")
        } else {
            // Fallback: try watching for the watch_now button
            let watchNow = app.buttons["main_watch_now"].firstMatch
            if watchNow.waitForExistence(timeout: 10) {
                app.tap()
                sleep(2)
            } else {
                sleep(5)
            }
            saveScreenshot("10_main_single_pick")
        }
    }

    /// 11. Carousel -- multiple picks (progressive picks flow)
    func test11_MainScreen_Carousel() throws {
        // openOTT is suppressed in screenshot-mode, so Netflix won't open
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "0",     // 0-19 = 5 picks carousel
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for carousel -- look for not_tonight or paging dots
        let notTonight = app.buttons["main_not_tonight"].firstMatch
        if notTonight.waitForExistence(timeout: 30) {
            app.tap()
            sleep(2)
            saveScreenshot("11_main_carousel")
        } else {
            sleep(10)
            saveScreenshot("11_main_carousel")
        }
    }

    /// 12. GoodScore close-up -- scroll down to show the GoodScore badge prominently
    func test12_GoodScoreCloseUp() throws {
        // openOTT is suppressed in screenshot-mode
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "200",
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for main screen
        let watchNow = app.buttons["main_watch_now"].firstMatch
        if watchNow.waitForExistence(timeout: 30) {
            app.tap()
            sleep(2)
        } else {
            sleep(10)
        }
        saveScreenshot("12_goodscore")
    }
}
