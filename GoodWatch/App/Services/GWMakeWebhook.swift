import Foundation

// ============================================
// GWMakeWebhook — Make.com Scenario Triggers
// ============================================
//
// Fire-and-forget webhooks to Make.com for automated workflows.
//
// Scenario 7: Day-1 Retention Alert
//   Triggered on first session end for new users.
//   Make.com handles: 24h wait -> check return -> send re-engagement push/email.
//
// Webhook is non-blocking, no-throw, fire-and-forget.
// ============================================

final class GWMakeWebhook {
    static let shared = GWMakeWebhook()
    private init() {}

    // Make.com webhook URL for Scenario 7: Day-1 Retention Alert
    // Scenario ID: 4832042 | Hook ID: 2650518 | Region: eu1
    private let day1RetentionURL = "https://hook.eu1.make.com/oqpsdhxagwnucmsenmld827cx1pqd4w5"

    // MARK: - Scenario 7: Day-1 Retention Alert

    /// Fire on first session end for new users.
    /// Sends user context to Make.com for 24h retention check.
    ///
    /// Only fires once per user (first session only).
    /// UserDefaults flag prevents duplicate fires.
    func fireDay1RetentionAlert(userId: String) {
        let firedKey = "gw_day1_retention_fired_\(userId)"
        guard !UserDefaults.standard.bool(forKey: firedKey) else { return }

        // Only fire for new users in their first session
        let sessionCount = UserDefaults.standard.integer(forKey: "gw_session_count")
        guard sessionCount <= 1 else { return }
        guard GWSubscriptionManager.shared.isNewUser else { return }

        // Mark as fired BEFORE sending (prevent double-fire)
        UserDefaults.standard.set(true, forKey: firedKey)

        let payload: [String: Any] = [
            "user_id": userId,
            "email": UserService.shared.currentUserEmail ?? "",
            "session_number": sessionCount,
            "accepted_count": GWSubscriptionManager.shared.cachedAcceptedCount,
            "rejected_count": GWSubscriptionManager.shared.cachedRejectedCount,
            "is_pro": GWSubscriptionManager.shared.isPro,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]

        Task {
            await sendWebhook(url: day1RetentionURL, payload: payload)
        }
    }

    // MARK: - Private

    private func sendWebhook(url: String, payload: [String: Any]) async {
        guard let webhookURL = URL(string: url) else { return }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        _ = try? await GWNetworkSession.shared.data(for: request)

        #if DEBUG
        print("[GWMake] Fired Day-1 Retention Alert for user: \(payload["user_id"] ?? "")")
        #endif
    }
}
