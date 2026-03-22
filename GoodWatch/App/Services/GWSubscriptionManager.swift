import Foundation
import RevenueCat
import PostHog
import OneSignalFramework

/// Manages subscription status and daily free-tier recommendation limits.
/// Free users get 3 recommendations per day. Pro users (via RevenueCat) get unlimited.
final class GWSubscriptionManager: ObservableObject {
    static let shared = GWSubscriptionManager()

    // MARK: - Published State

    @Published private(set) var isPro: Bool = false

    // MARK: - Cold Start State (Task 3 will expand these)

    /// Stored Bool — populated once on login via refreshNewUserStatus(userId:)
    /// NOT a computed property (computed properties cannot be async)
    private(set) var isNewUser: Bool = false

    /// Total interaction count (accepted + rejected) from Supabase
    private(set) var cachedInteractionCount: Int = 0

    /// Accepted interaction count from Supabase
    var cachedAcceptedCount: Int = 0

    /// Rejected interaction count from Supabase
    var cachedRejectedCount: Int = 0

    /// Per-session flag: has cold_start_paywall_bypass been fired this session?
    /// Reset to false on every app launch before session counter.
    var hasFiredBypassThisSession: Bool = false

    /// In-session reject counter (for cold_start_completed event)
    private var rejectedCount: Int = 0

    /// Thumbs up ratings given (for cold_start_completed event)
    private(set) var thumbsUpCount: Int = 0

    /// Account creation date (fetched from Supabase on login)
    private var accountCreatedAt: Date?

    /// Session count (tracked via UserDefaults for cold start paywall logic)
    private var sessionCount: Int {
        UserDefaults.standard.integer(forKey: "gw_session_count")
    }

    // MARK: - UserDefaults Keys

    private let dailyCountKey = "gw_daily_recommendation_count"
    private let dailyDateKey = "gw_daily_recommendation_date"
    private let installDateKey = "gw_install_date"

    // MARK: - Constants

    /// Standard free limit from Firebase Remote Config (default 3).
    private var standardFreeLimit: Int {
        return GWRemoteConfig.shared.freeLimit
    }

    /// Effective free limit: cold start users get 5/day (sessions 2+), graduated users get standard limit.
    /// First session (sessionCount == 1) for cold start users: unlimited (paywall bypassed).
    var effectiveFreeLimit: Int {
        if isPro { return Int.max }
        if isNewUser {
            if sessionCount <= 1 { return Int.max }  // First session: unlimited
            return 5  // Cold start sessions 2+: 5 free/day
        }
        return standardFreeLimit  // Graduated: standard limit (default 3)
    }

    // MARK: - Init

    private init() {
        resetDailyCountIfNeeded()
    }

    // MARK: - Public API

    /// Current number of recommendations used today (resets at midnight).
    var dailyRecommendationCount: Int {
        resetDailyCountIfNeeded()
        return UserDefaults.standard.integer(forKey: dailyCountKey)
    }

    /// Whether the user can receive another recommendation right now.
    /// Pro users: always true. Cold start first session: always true.
    /// Cold start sessions 2+: 5/day (accepts only). Graduated: standard limit.
    var canGetRecommendation: Bool {
        resetDailyCountIfNeeded()
        if isPro { return true }

        let limit = effectiveFreeLimit
        if limit == Int.max { return true }  // Unlimited (first cold start session)

        let allowed = dailyRecommendationCount < limit
        if !allowed {
            // Fire cold start paywall bypass event once per session
            if isNewUser && !hasFiredBypassThisSession {
                hasFiredBypassThisSession = true
                PostHogSDK.shared.capture("cold_start_paywall_bypass", properties: [
                    "session_count": sessionCount,
                    "daily_count": dailyRecommendationCount,
                    "interaction_count": cachedInteractionCount
                ])
            }

            PostHogSDK.shared.capture("daily_limit_hit", properties: [
                "daily_count": dailyRecommendationCount,
                "is_cold_start": isNewUser,
                "effective_limit": limit
            ])
        }
        return allowed
    }

    /// Fetch the latest CustomerInfo from RevenueCat and update isPro.
    func refreshStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let wasPro = isPro
            let active = customerInfo.entitlements["GoodWatch Movies Pro"]?.isActive == true
            await MainActor.run {
                self.isPro = active
            }

            // PostHog: track new subscription if status changed to Pro
            if active && !wasPro {
                // Extract product info from active entitlement
                let entitlement = customerInfo.entitlements["GoodWatch Movies Pro"]
                let productId = entitlement?.productIdentifier ?? "unknown"
                PostHogSDK.shared.capture("subscription_purchased", properties: [
                    "product_id": productId
                ])

                // ZeptoMail: send subscription confirmation email
                if let email = UserService.shared.currentUserEmail {
                    GWEmailService.shared.sendSubscriptionConfirmation(to: email, productId: productId)
                }
            }

            // OneSignal: update segmentation tags
            OneSignal.User.addTag(key: "is_pro", value: active ? "true" : "false")
            OneSignal.User.addTag(key: "daily_count", value: "\(dailyRecommendationCount)")

            #if DEBUG
            print("[GWSubscription] Refreshed status: isPro = \(active)")
            #endif
        } catch {
            #if DEBUG
            print("[GWSubscription] Failed to fetch customer info: \(error.localizedDescription)")
            #endif
        }
    }

    /// Increment the daily recommendation counter.
    /// During cold start: only accepted recs count toward 5/day limit.
    /// Rejected recs do NOT increment daily count during cold start.
    /// Also tracks total interaction count for 50-threshold graduation.
    ///
    /// - Parameter wasAccepted: true for watch_now, false for not_tonight/already_seen/show_another
    func incrementRecommendationCount(wasAccepted: Bool = true) {
        // Snapshot isNewUser BEFORE any mutation
        let wasNewUserAtCallTime = isNewUser

        // Counter A: Total interaction count (both accepted + rejected)
        cachedInteractionCount += 1

        if !wasAccepted {
            rejectedCount += 1
            cachedRejectedCount += 1
        } else {
            cachedAcceptedCount += 1
        }

        // Counter B: Daily recommendation count (for paywall)
        // During cold start: only accepts count. After graduation: all count.
        if wasNewUserAtCallTime && !wasAccepted {
            // Cold start rejected rec: do NOT increment daily count
            #if DEBUG
            print("[GWSubscription] Cold start reject: skipping daily count increment")
            #endif
        } else {
            resetDailyCountIfNeeded()
            let current = UserDefaults.standard.integer(forKey: dailyCountKey)
            UserDefaults.standard.set(current + 1, forKey: dailyCountKey)
            #if DEBUG
            print("[GWSubscription] Recommendation count: \(current + 1)/\(effectiveFreeLimit)")
            #endif
        }

        // Check cold start graduation at 50 interactions
        if wasNewUserAtCallTime && cachedInteractionCount >= 50 {
            isNewUser = false
            PostHogSDK.shared.capture("cold_start_completed", properties: [
                "total_interactions": cachedInteractionCount,
                "accepted_count": cachedAcceptedCount,
                "rejected_count": cachedRejectedCount,
                "thumbs_up_count": thumbsUpCount
            ])
            #if DEBUG
            print("[GWSubscription] Cold start graduated at \(cachedInteractionCount) interactions")
            #endif
        }
    }

    /// Increment thumbs up count (called from rating handler)
    func incrementThumbsUp() {
        thumbsUpCount += 1
    }

    // MARK: - Cold Start: New User Status

    /// Fetch interaction count + account age from Supabase to determine isNewUser.
    /// Call on login, BEFORE session counter increments and app_opened fires.
    /// Cold start entry: count < 50 AND age < 30 days.
    /// Cold start exit: count >= 50 OR age >= 30 days.
    func refreshNewUserStatus(userId: String) async {
        let baseURL = SupabaseConfig.url
        let anonKey = SupabaseConfig.anonKey

        // Fetch interaction count (accepted + rejected)
        let countURL = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId)&action=in.(watch_now,not_tonight,already_seen)&select=id"
        if let url = URL(string: countURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("exact", forHTTPHeaderField: "Prefer")

            if let (data, _) = try? await GWNetworkSession.shared.data(for: request) {
                struct IdRow: Decodable { let id: String }
                if let rows = try? JSONDecoder().decode([IdRow].self, from: data) {
                    cachedInteractionCount = rows.count
                }
            }
        }

        // Fetch accepted count
        let acceptURL = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId)&action=eq.watch_now&select=id"
        if let url = URL(string: acceptURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

            if let (data, _) = try? await GWNetworkSession.shared.data(for: request) {
                struct IdRow: Decodable { let id: String }
                if let rows = try? JSONDecoder().decode([IdRow].self, from: data) {
                    cachedAcceptedCount = rows.count
                }
            }
        }

        // Fetch rejected count
        let rejectURL = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId)&action=in.(not_tonight,already_seen)&select=id"
        if let url = URL(string: rejectURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

            if let (data, _) = try? await GWNetworkSession.shared.data(for: request) {
                struct IdRow: Decodable { let id: String }
                if let rows = try? JSONDecoder().decode([IdRow].self, from: data) {
                    cachedRejectedCount = rows.count
                }
            }
        }

        // Fetch account_created_at from user_profiles
        let profileURL = "\(baseURL)/rest/v1/user_profiles?user_id=eq.\(userId)&select=account_created_at"
        if let url = URL(string: profileURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

            struct ProfileRow: Decodable {
                let account_created_at: String?
            }

            if let (data, _) = try? await GWNetworkSession.shared.data(for: request) {
                if let rows = try? JSONDecoder().decode([ProfileRow].self, from: data),
                   let dateStr = rows.first?.account_created_at {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    accountCreatedAt = formatter.date(from: dateStr)
                }
            }
        }

        // Determine isNewUser: count < 50 AND account age < 30 days
        let accountAge: Int
        if let created = accountCreatedAt {
            accountAge = Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0
        } else {
            // Null/missing account_created_at: treat as brand new
            accountAge = 0
        }

        isNewUser = cachedInteractionCount < 50 && accountAge < 30

        #if DEBUG
        print("[GWSubscription] New user status: isNewUser=\(isNewUser), interactions=\(cachedInteractionCount), accountAge=\(accountAge) days, accepted=\(cachedAcceptedCount), rejected=\(cachedRejectedCount)")
        #endif
    }

    /// Increment session count. Call once per app launch.
    func incrementSessionCount() {
        let current = UserDefaults.standard.integer(forKey: "gw_session_count")
        UserDefaults.standard.set(current + 1, forKey: "gw_session_count")

        // Store install date on first launch
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
    }

    // MARK: - Private

    /// Reset the daily counter if the stored date doesn't match today.
    private func resetDailyCountIfNeeded() {
        let stored = UserDefaults.standard.string(forKey: dailyDateKey) ?? ""
        let today = todayString()
        if stored != today {
            UserDefaults.standard.set(0, forKey: dailyCountKey)
            UserDefaults.standard.set(today, forKey: dailyDateKey)
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the user has exhausted free recommendations and needs to see the paywall.
    static let gwShowPaywall = Notification.Name("GWShowPaywall")
}
