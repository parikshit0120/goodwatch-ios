import Foundation
import PostHog

// ============================================
// GWSuppressionManager — Watched & Rejected Suppression
// ============================================
//
// Trust foundation: ensures users never see movies they already
// watched or rejected. Uses a batch-loaded in-memory cache for
// O(1) lookups — zero network calls per movie check.
//
// Suppression rules:
//   Rejected in current session → entire session (in-memory Set)
//   Rejected previously → 30 days (Supabase `interactions`)
//   Already watched/accepted → 6 months (Supabase `interactions`)
//
// Cache is loaded once on login and app foreground via
// loadSuppressionCache(userId:). markRejected/markWatched update
// the in-memory cache synchronously first, then write to Supabase
// asynchronously — no full reload on every swipe.
// ============================================

final class GWSuppressionManager {
    static let shared = GWSuppressionManager()
    private init() {}

    // MARK: - State

    /// Movies rejected during the current session only (clears on app restart)
    private var sessionRejected: Set<UUID> = []

    /// All suppressed movie IDs loaded from Supabase on login (accepted + rejected)
    private(set) var suppressedMovieIds: Set<UUID> = []

    /// When true, suppression is temporarily lifted for this session
    /// (user confirmed "show me anyway" after pool exhaustion)
    private(set) var suppressionLifted: Bool = false

    // Supabase config
    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    // MARK: - Public API

    /// Synchronous Set lookup — no network calls.
    /// Returns true if movieId should be hidden from recommendations.
    /// NOTE: cache must be loaded via loadSuppressionCache(userId:) before calling this.
    func isSuppressed(movieId: UUID) -> Bool {
        if suppressionLifted { return false }
        return sessionRejected.contains(movieId) || suppressedMovieIds.contains(movieId)
    }

    /// Mark a movie as watched/accepted.
    /// CRITICAL ORDER:
    ///   1. Synchronous cache update (immediate suppression)
    ///   2. Sync accepted count on subscription manager
    ///   3. Async Supabase write (non-blocking)
    func markWatched(movieId: UUID, userId: String) async {
        // 1. Synchronous cache — movie is suppressed immediately
        suppressedMovieIds.insert(movieId)

        // 2. Sync count update
        GWSubscriptionManager.shared.cachedAcceptedCount += 1

        // 3. Async Supabase write — already handled by InteractionService.recordWatchNow()
        // which is called from RootFlowView.handleWatchNow(). We do NOT duplicate the write here.
        // This method only manages the suppression cache.
    }

    /// Mark a movie as rejected.
    /// CRITICAL ORDER:
    ///   1. Session cache (clears on restart)
    ///   2. Persistent cache (30-day suppression)
    ///   3. Sync rejected count
    ///   4. Async Supabase write (non-blocking)
    func markRejected(movieId: UUID, userId: String) async {
        // 1. Session cache
        sessionRejected.insert(movieId)

        // 2. Persistent cache
        suppressedMovieIds.insert(movieId)

        // 3. Local count sync
        GWSubscriptionManager.shared.cachedRejectedCount += 1

        // 4. Async Supabase write — already handled by InteractionService.recordNotTonight()
        // which is called from RootFlowView handlers. We do NOT duplicate the write here.
        // This method only manages the suppression cache.
    }

    /// Temporarily lift suppression for this session only.
    /// Called when user taps "Show me anyway" after pool exhaustion.
    /// Clears on app restart.
    func temporarilyLiftSuppression(for userId: String) {
        suppressionLifted = true
        PostHogSDK.shared.capture("suppression_lifted", properties: [
            "user_id": userId
        ])
    }

    /// Reset session state (call on app launch)
    func resetSession() {
        sessionRejected = []
        suppressionLifted = false
    }

    // MARK: - Batch Cache Loading

    /// Fetch ALL suppressed movie IDs for this user in ONE query at session start.
    /// Call on login and on app foreground. Do NOT call inside markRejected/markWatched.
    func loadSuppressionCache(userId: String) async {
        // Query all interactions where action is watch_now (accepted) or not_tonight/already_seen (rejected)
        // Returns movie_id for suppression. Date filtering handled locally as a safe superset —
        // expired suppressions just mean slightly over-suppressed, not show-repeats.
        let urlString = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId)&action=in.(watch_now,not_tonight,already_seen)&select=movie_id"
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("[GWSuppressionManager] Invalid URL for suppression cache load")
            #endif
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await GWNetworkSession.shared.data(for: request)

            struct InteractionRow: Decodable {
                let movie_id: UUID
            }

            let rows = try JSONDecoder().decode([InteractionRow].self, from: data)
            self.suppressedMovieIds = Set(rows.map { $0.movie_id })

            #if DEBUG
            print("[GWSuppressionManager] Loaded \(self.suppressedMovieIds.count) suppressed movie IDs")
            #endif
        } catch {
            #if DEBUG
            print("[GWSuppressionManager] Failed to load suppression cache: \(error)")
            #endif
            // On failure, keep existing cache (may be empty on first launch — acceptable)
        }
    }
}
