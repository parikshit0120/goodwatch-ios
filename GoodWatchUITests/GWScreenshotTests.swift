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
        // Wait for auth screen to fully appear
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

    /// Navigate from Landing to Duration screen
    private func goToDuration() {
        goToPlatform()
        // Select platforms + language
        selectPlatformsAndLanguage()
        _ = tapElement("platform_continue", fallbackText: "Continue", timeout: 3)
        _ = waitForScreen("duration_card_0", fallbackText: "How long do you want", timeout: 8)
        sleep(1)
    }

    /// Select platforms (Select all) and English language on Platform screen
    private func selectPlatformsAndLanguage() {
        let selectAll = app.buttons["Select all"].firstMatch
        if selectAll.waitForExistence(timeout: 3) && selectAll.isHittable {
            selectAll.tap()
        } else {
            _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        }
        sleep(1)

        // English — LanguageChip is a Button
        let englishBtn = app.buttons["English"].firstMatch
        if englishBtn.waitForExistence(timeout: 3) && englishBtn.isHittable {
            englishBtn.tap()
        } else {
            let english = app.staticTexts["English"].firstMatch
            if english.waitForExistence(timeout: 2) && english.isHittable {
                english.tap()
            }
        }
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

    /// 3. Mood selector screen (no selection — gray Continue)
    func test03_MoodSelector() throws {
        app.launch()
        goToMood()
        saveScreenshot("03_mood_selector")
    }

    /// 4. Mood selected state (Feel-good highlighted — gold Continue)
    func test04_MoodSelected() throws {
        app.launch()
        goToMood()
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        saveScreenshot("04_mood_selected")
    }

    /// 5. Platform selector with language chips
    func test05_PlatformSelector() throws {
        app.launch()
        goToPlatform()
        saveScreenshot("05_platform_selector")
    }

    /// 6. Duration selector (3 options: 90min / 2-2.5hr / Series)
    func test06_DurationSelector() throws {
        app.launch()
        goToDuration()
        saveScreenshot("06_duration_selector")
    }

    /// 7. Confidence moment / loading screen
    func test07_ConfidenceMoment() throws {
        // DON'T skip loading delay — we want to capture the animation
        app.launchArguments = [
            "--screenshot-mode",
            "--reset-onboarding",
            "--interaction-points", "200",
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // ConfidenceMoment should appear — capture immediately
        let confidence = app.otherElements["confidence_moment_screen"].firstMatch
        if confidence.waitForExistence(timeout: 5) {
            // Capture during animation (don't wait too long or it will transition)
            saveScreenshot("07_confidence_moment")
        } else {
            // Might have already transitioned — capture whatever is showing
            saveScreenshot("07_confidence_moment")
        }
    }

    /// 8. Main recommendation screen — single pick with GoodScore
    func test08_MainScreen_SinglePick() throws {
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "200",   // 160+ = single pick
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for recommendation to load (poster + GoodScore)
        let watchNow = app.buttons["main_watch_now"].firstMatch
        if watchNow.waitForExistence(timeout: 15) {
            sleep(3)  // Let poster fully render
            saveScreenshot("08_main_single_pick")
        } else {
            sleep(5)
            saveScreenshot("08_main_single_pick")
        }
    }

    /// 9. Carousel — multiple picks (progressive picks flow)
    func test09_MainScreen_Carousel() throws {
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "0",     // 0-19 = 5 picks carousel
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for carousel to load — look for paging dots or the carousel itself
        // Give it extra time for multiple movie fetches
        sleep(10)
        saveScreenshot("09_main_carousel")
    }

    /// 10. Platform selector with selections made (Netflix + Hindi shown)
    func test10_PlatformSelected() throws {
        app.launch()
        goToPlatform()

        // Make selections to show the "selected" state
        _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        sleep(1)

        // Select Hindi language to show a different language selected
        let hindi = app.buttons["Hindi"].firstMatch
        if hindi.waitForExistence(timeout: 3) && hindi.isHittable {
            hindi.tap()
        }
        sleep(1)
        saveScreenshot("10_platform_selected")
    }

    /// 11. Duration selector with selection (2-2.5 hours highlighted)
    func test11_DurationSelected() throws {
        app.launch()
        goToDuration()

        // Select "2-2.5 hours" to show gold border + gold Continue
        if !tapElement("duration_card_1", timeout: 5) {
            let fullMovie = app.buttons["2-2.5 hours"].firstMatch
            if fullMovie.waitForExistence(timeout: 3) && fullMovie.isHittable {
                fullMovie.tap()
            }
        }
        sleep(1)
        saveScreenshot("11_duration_selected")
    }

    /// 12. GoodScore close-up — capture just the recommendation with score visible
    func test12_GoodScoreCloseUp() throws {
        app.launchArguments = [
            "--screenshot-mode",
            "--skip-loading-delay",
            "--reset-onboarding",
            "--interaction-points", "200",
            "--force-feature-flag", "progressive_picks"
        ]
        app.launch()

        navigateThroughOnboarding()

        // Wait for recommendation with GoodScore
        let watchNow = app.buttons["main_watch_now"].firstMatch
        if watchNow.waitForExistence(timeout: 15) {
            sleep(4)  // Let everything render including GoodScore animation
            saveScreenshot("12_goodscore")
        } else {
            sleep(5)
            saveScreenshot("12_goodscore")
        }
    }
}
