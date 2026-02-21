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
            let staticText = app.staticTexts[text].firstMatch
            if staticText.waitForExistence(timeout: 3) && staticText.isHittable {
                staticText.tap()
                return true
            }
            // Also try as button label
            let button = app.buttons[text].firstMatch
            if button.waitForExistence(timeout: 2) && button.isHittable {
                button.tap()
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

    /// Navigate through full onboarding: Landing -> Auth(skip) -> Mood -> Platform -> Duration
    private func navigateThroughOnboarding() {
        // 1. Landing -> tap Pick for me
        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        // 2. Auth -> tap Skip
        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)

        // 3. Mood selector -> tap first mood card (Feel-good)
        if !tapElement("mood_card_0", timeout: 5) {
            // Fallback: tap "Feel-good" text directly
            let feelGood = app.staticTexts["Feel-good"].firstMatch
            if feelGood.waitForExistence(timeout: 3) && feelGood.isHittable {
                feelGood.tap()
            }
        }
        sleep(1)

        // Tap mood Continue
        _ = tapElement("mood_continue", fallbackText: "Continue", timeout: 3)
        sleep(1)

        // 4. Platform selector -> should now show "Which platforms do you have?"
        // Wait for platform screen to appear
        _ = waitForScreen("platform_netflix", fallbackText: "Which platforms do you have?", timeout: 5)

        // Tap "Select all" to quickly select all platforms
        let selectAll = app.buttons["Select all"].firstMatch
        if selectAll.waitForExistence(timeout: 3) && selectAll.isHittable {
            selectAll.tap()
        } else {
            // Fallback: tap Netflix
            _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        }
        sleep(1)

        // Select English language — try button first (LanguageChip is a Button)
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

        // Tap platform Continue
        _ = tapElement("platform_continue", fallbackText: "Continue", timeout: 3)
        sleep(2)

        // 5. Duration selector -> should show "How long do you want to watch?"
        _ = waitForScreen("duration_card_0", fallbackText: "How long do you want", timeout: 8)

        // Tap "2-2.5 hours" (index 1) — DurationCard is a Button
        if !tapElement("duration_card_1", timeout: 5) {
            // Try tapping the button containing "2-2.5 hours"
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

        // Tap duration Continue
        _ = tapElement("duration_continue", fallbackText: "Continue", timeout: 3)
        sleep(2)
    }

    // MARK: - Screenshot Tests

    /// 1. Landing screen with poster grid
    func test01_LandingScreen() throws {
        app.launch()

        // Wait for landing to fully load (posters take a moment)
        _ = waitForScreen("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(3)
        saveScreenshot("01_landing")
    }

    /// 2. Auth screen
    func test02_AuthScreen() throws {
        app.launch()

        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        _ = waitForScreen("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)
        saveScreenshot("02_auth")
    }

    /// 3. Mood selector screen (no selection)
    func test03_MoodSelector() throws {
        app.launch()

        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)

        // Wait for mood screen to appear
        _ = waitForScreen("mood_card_0", fallbackText: "What's the vibe?", timeout: 5)
        sleep(1)
        saveScreenshot("03_mood_selector")
    }

    /// 4. Mood selected state (Feel-good highlighted)
    func test04_MoodSelected() throws {
        app.launch()

        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)

        // Wait for mood screen
        _ = waitForScreen("mood_card_0", fallbackText: "What's the vibe?", timeout: 5)
        sleep(1)

        // Tap first mood to highlight it
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        saveScreenshot("04_mood_selected")
    }

    /// 5. Platform selector screen
    func test05_PlatformSelector() throws {
        app.launch()

        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)

        // Select mood + continue
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        _ = tapElement("mood_continue", fallbackText: "Continue", timeout: 3)
        sleep(1)

        // Wait for platform screen
        _ = waitForScreen("platform_netflix", fallbackText: "Which platforms do you have?", timeout: 5)
        sleep(1)
        saveScreenshot("05_platform_selector")
    }

    /// 6. Duration selector screen
    func test06_DurationSelector() throws {
        app.launch()

        _ = tapElement("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(1)

        _ = tapElement("auth_skip", fallbackText: "Continue without account", timeout: 5)
        sleep(1)

        // Mood: select + continue
        _ = tapElement("mood_card_0", fallbackText: "Feel-good", timeout: 5)
        sleep(1)
        _ = tapElement("mood_continue", fallbackText: "Continue", timeout: 3)
        sleep(1)

        // Platform: select all + English + continue
        _ = waitForScreen("platform_netflix", fallbackText: "Which platforms do you have?", timeout: 5)
        let selectAll = app.buttons["Select all"].firstMatch
        if selectAll.waitForExistence(timeout: 3) && selectAll.isHittable {
            selectAll.tap()
        } else {
            _ = tapElement("platform_netflix", fallbackText: "Netflix", timeout: 3)
        }
        sleep(1)

        // English is a Button (LanguageChip uses Button with .buttonStyle(.plain))
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

        _ = tapElement("platform_continue", fallbackText: "Continue", timeout: 3)
        sleep(2)

        // Wait for duration screen
        _ = waitForScreen("duration_card_0", fallbackText: "How long do you want", timeout: 8)
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

        // ConfidenceMoment should appear — capture it quickly
        let confidence = app.otherElements["confidence_moment_screen"].firstMatch
        if confidence.waitForExistence(timeout: 5) {
            sleep(1)
            saveScreenshot("07_confidence_moment")
        } else {
            // May have already transitioned — capture whatever is on screen
            sleep(1)
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
            sleep(3)  // Let poster load
            saveScreenshot("08_main_single_pick")
        } else {
            // Recommendation may not have loaded (no network) — capture anyway
            sleep(5)
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
        sleep(8)  // Let multiple posters load
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
            sleep(2)
            saveScreenshot("10_enjoy_screen")
        } else {
            sleep(3)
            saveScreenshot("10_enjoy_screen")
        }
    }

    /// 11. Landing with Explore button visible
    func test11_LandingWithExplore() throws {
        app.launch()

        let explore = app.buttons["landing_explore"].firstMatch
        if explore.waitForExistence(timeout: 10) {
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
        _ = waitForScreen("landing_pick_for_me", fallbackText: "Pick for me", timeout: 10)
        sleep(2)
        saveScreenshot("12_landing_clean")
    }
}
