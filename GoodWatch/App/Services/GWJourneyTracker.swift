import Foundation
import PostHog

// ============================================
// GWJourneyTracker — PostHog User Journey Events
// ============================================
//
// Centralized tracker for 18 PostHog user journey events.
// Events are grouped into journey milestones for first-impression
// launch readiness tracking.
//
// Event list:
//   1.  app_opened
//   2.  onboarding_started
//   3.  onboarding_completed
//   4.  mood_selected
//   5.  platform_selected
//   6.  recommendation_shown        (via MetricsService)
//   7.  recommendation_accepted     (via MetricsService)
//   8.  recommendation_rejected     (via MetricsService)
//   9.  movie_rated                 (via GWRatingService)
//   10. daily_limit_hit             (via GWSubscriptionManager)
//   11. paywall_shown               (via GWPaywallView)
//   12. paywall_converted           (via GWPaywallView)
//   13. paywall_dismissed           (via GWPaywallView)
//   14. subscription_purchased      (via GWSubscriptionManager)
//   15. cold_start_completed        (via GWSubscriptionManager)
//   16. mood_mismatch               (via MovieRecommendationService)
//   17. quality_floor_fallback      (via MovieRecommendationService)
//   18. session_ended
// ============================================

final class GWJourneyTracker {
    static let shared = GWJourneyTracker()
    private init() {}

    // Session-scoped counters (reset on app launch)
    private var sessionAccepted: Int = 0
    private var sessionRejected: Int = 0
    private var sessionRated: Int = 0

    // MARK: - 1. App Opened

    func trackAppOpened() {
        let sessionCount = UserDefaults.standard.integer(forKey: "gw_session_count")
        PostHogSDK.shared.capture("app_opened", properties: [
            "session_number": sessionCount,
            "is_new_user": GWSubscriptionManager.shared.isNewUser,
            "is_pro": GWSubscriptionManager.shared.isPro,
            "interaction_count": GWSubscriptionManager.shared.cachedInteractionCount
        ])
    }

    // MARK: - 2. Onboarding Started

    func trackOnboardingStarted() {
        PostHogSDK.shared.capture("onboarding_started", properties: [
            "is_new_user": GWSubscriptionManager.shared.isNewUser,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count"),
            "is_returning": GWOnboardingMemory.shared.hasSavedSelections
        ])
    }

    // MARK: - 3. Onboarding Completed

    func trackOnboardingCompleted(mood: String, platforms: [String], skippedSteps: Bool) {
        PostHogSDK.shared.capture("onboarding_completed", properties: [
            "mood": mood,
            "platform_count": platforms.count,
            "platforms": platforms,
            "skipped_steps": skippedSteps,
            "is_new_user": GWSubscriptionManager.shared.isNewUser,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count")
        ])
    }

    // MARK: - 4. Mood Selected

    func trackMoodSelected(mood: String) {
        PostHogSDK.shared.capture("mood_selected", properties: [
            "mood": mood,
            "is_new_user": GWSubscriptionManager.shared.isNewUser,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count")
        ])
    }

    // MARK: - 5. Platform Selected

    func trackPlatformSelected(platforms: [String]) {
        PostHogSDK.shared.capture("platform_selected", properties: [
            "platforms": platforms,
            "platform_count": platforms.count,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count")
        ])
    }

    // MARK: - Session Counters (called by existing event handlers)

    func recordAccept() { sessionAccepted += 1 }
    func recordReject() { sessionRejected += 1 }
    func recordRating() { sessionRated += 1 }

    // MARK: - 18. Session Ended

    func trackSessionEnded() {
        PostHogSDK.shared.capture("session_ended", properties: [
            "accepted_count": sessionAccepted,
            "rejected_count": sessionRejected,
            "rated_count": sessionRated,
            "is_new_user": GWSubscriptionManager.shared.isNewUser,
            "is_pro": GWSubscriptionManager.shared.isPro,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count"),
            "daily_recommendation_count": GWSubscriptionManager.shared.dailyRecommendationCount
        ])
    }

    // MARK: - Reset (call on app launch)

    func resetSession() {
        sessionAccepted = 0
        sessionRejected = 0
        sessionRated = 0
    }
}
