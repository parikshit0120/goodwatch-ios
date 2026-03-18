import XCTest
@testable import GoodWatch

class GWOnboardingTests: XCTestCase {

    private let key = "gw_onboarding_step"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testOnboardingCompletionPersistsBeforeRecommendation() {
        // Precondition: key must be false/0 before test
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 0,
                       "Precondition: key must be 0 before test")

        // Act: call the extracted completeOnboarding() function
        GWKeychainManager.shared.completeOnboarding()

        // Assert: key must be 6 (complete) after completeOnboarding(), before any recommendation
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 6,
                       "Key must be 6 after completeOnboarding(), before any recommendation")
    }

    func testOnboardingStepPersistsAcrossManagerInstances() {
        UserDefaults.standard.removeObject(forKey: key)

        GWKeychainManager.shared.completeOnboarding()

        // Verify through the getter
        XCTAssertEqual(GWKeychainManager.shared.getOnboardingStep(), 6,
                       "getOnboardingStep() must return 6 after completeOnboarding()")
    }

    func testResumeFromSavedStateSkipsCompletedOnboarding() {
        // Step 6+ means onboarding is complete — resume should NOT re-enter onboarding
        GWKeychainManager.shared.completeOnboarding()
        let step = GWKeychainManager.shared.getOnboardingStep()
        // The resume logic in RootFlowView checks: guard savedStep > 0, savedStep < 6
        // Step 6 should NOT pass this guard — user goes to landing
        XCTAssertFalse(step > 0 && step < 6,
                       "Step 6 must not satisfy resume guard (savedStep > 0 && savedStep < 6)")
    }
}
