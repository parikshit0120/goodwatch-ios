import Foundation
import PostHog

// ============================================
// GWRatingService — Post-Watch Rating System
// ============================================
//
// Manages the "How was it?" thumbs up/down rating flow.
// Pending ratings are stored in UserDefaults as [PendingRating].
// On return session, the most recent unrated movie triggers a banner.
//
// Rating signals:
//   Thumbs up -> 2x weight on genre/mood tags, increment thumbsUpCount
//   Thumbs down -> 0x weight, 30-day suppression (same as reject)
// ============================================

struct PendingRating: Codable {
    let movieId: String      // UUID string
    let movieTitle: String   // For display in banner
    let posterPath: String?  // For thumbnail in banner
    let addedAtSession: Int  // Session number when accepted
    let interactedAt: Date   // Timestamp when movie was accepted
    let movieTags: [String]  // Tags for taste profile boost/penalize
}

final class GWRatingService {
    static let shared = GWRatingService()
    private init() {}

    private let pendingKey = "gw_pending_ratings"

    // MARK: - Public API

    /// Add a pending rating when user accepts a movie (swipe right / watch now).
    func addPendingRating(
        movieId: String,
        movieTitle: String,
        posterPath: String?,
        movieTags: [String]
    ) {
        var pending = loadPending()
        let entry = PendingRating(
            movieId: movieId,
            movieTitle: movieTitle,
            posterPath: posterPath,
            addedAtSession: UserDefaults.standard.integer(forKey: "gw_session_count"),
            interactedAt: Date(),
            movieTags: movieTags
        )
        pending.append(entry)
        savePending(pending)
    }

    /// Get the most recent pending rating eligible for banner display.
    /// Returns nil if no pending ratings within 3 sessions.
    func getPendingForBanner() -> PendingRating? {
        let currentSession = UserDefaults.standard.integer(forKey: "gw_session_count")
        var pending = loadPending()

        // Clean up: remove entries older than 3 sessions
        pending.removeAll { currentSession - $0.addedAtSession >= 3 }
        savePending(pending)

        // Only show on session 2+ (not on same session as accept)
        guard currentSession >= 2 else { return nil }

        // Return most recent entry that was added in a PREVIOUS session
        return pending
            .filter { $0.addedAtSession < currentSession }
            .sorted { $0.interactedAt > $1.interactedAt }
            .first
    }

    /// Process a rating (thumbs up or thumbs down).
    func rateMovie(movieId: String, thumbsUp: Bool, userId: String) async {
        // 1. Update Supabase (rating + rated_at on interactions row)
        await updateSupabaseRating(movieId: movieId, thumbsUp: thumbsUp, userId: userId)

        // 2. Taste profile boost/penalize
        if thumbsUp {
            // Thumbs up: boost tags 2x and increment thumbsUpCount
            if let entry = loadPending().first(where: { $0.movieId == movieId }) {
                boostTags(tags: entry.movieTags, multiplier: 0.30)  // +0.30 per tag (2x normal watch_now +0.15)
            }
            GWSubscriptionManager.shared.incrementThumbsUp()
        } else {
            // Thumbs down: penalize tags and suppress
            if let entry = loadPending().first(where: { $0.movieId == movieId }) {
                boostTags(tags: entry.movieTags, multiplier: -0.40)  // Same as abandoned
            }
            // Add to suppression (same as reject)
            if let uuid = UUID(uuidString: movieId) {
                await GWSuppressionManager.shared.markRejected(movieId: uuid, userId: userId)
            }
        }

        // 3. PostHog tracking
        let entry = loadPending().first(where: { $0.movieId == movieId })
        let daysSince = entry.map {
            Calendar.current.dateComponents([.day], from: $0.interactedAt, to: Date()).day ?? 0
        } ?? 0

        PostHogSDK.shared.capture("movie_rated", properties: [
            "movie_id": movieId,
            "rating": thumbsUp ? "positive" : "negative",
            "days_since_watched": daysSince,
            "is_cold_start_movie": GWSubscriptionManager.shared.isNewUser,
            "session_number": UserDefaults.standard.integer(forKey: "gw_session_count")
        ])

        // 4. Remove from pending
        removePending(movieId: movieId)
    }

    // MARK: - Private

    private func loadPending() -> [PendingRating] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([PendingRating].self, from: data)) ?? []
    }

    private func savePending(_ pending: [PendingRating]) {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func removePending(movieId: String) {
        var pending = loadPending()
        pending.removeAll { $0.movieId == movieId }
        savePending(pending)
    }

    private func boostTags(tags: [String], multiplier: Double) {
        var weights = TagWeightStore.shared.getWeights()
        for tag in tags {
            let current = weights[tag] ?? 1.0
            weights[tag] = max(0.1, current + multiplier)
        }
        TagWeightStore.shared.saveWeights(weights)
    }

    private func updateSupabaseRating(movieId: String, thumbsUp: Bool, userId: String) async {
        let baseURL = SupabaseConfig.url
        let anonKey = SupabaseConfig.anonKey

        let urlString = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId)&movie_id=eq.\(movieId)&action=eq.watch_now"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let ratedAt = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = ["rating": thumbsUp, "rated_at": ratedAt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await GWNetworkSession.shared.data(for: request)

        #if DEBUG
        print("[GWRating] Updated Supabase: movieId=\(movieId), rating=\(thumbsUp)")
        #endif
    }
}
