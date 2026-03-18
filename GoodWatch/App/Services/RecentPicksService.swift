import Foundation

// ============================================
// RECENT PICKS SERVICE
// ============================================
// Persists the last 5 recommended movies for display on the Landing screen.
// Provides visual recall so users can remember past recommendations.
//
// Storage: UserDefaults (lightweight, no auth required).
// Max picks: 5 (most recent first).
// ============================================

final class RecentPicksService {
    static let shared = RecentPicksService()
    private init() {}

    private let key = "gw_recent_picks"
    private let maxPicks = 5

    // MARK: - Lightweight pick data (only what Landing needs)

    struct RecentPick: Codable, Identifiable {
        let id: String
        let title: String
        let posterPath: String?
        let goodScore: Int
        let platformDisplayName: String?
        let deepLinkURL: String?
        let webURL: String?
        let year: Int?  // Optional so existing encoded data decodes without crash

        /// Poster URL for display. Handles both full URLs and TMDB paths.
        var posterURL: String? {
            guard let path = posterPath, !path.isEmpty else { return nil }
            if path.hasPrefix("http") { return path }
            return "https://image.tmdb.org/t/p/w185\(path)"
        }

        /// Whether this pick has a watchable link (deeplink or web).
        var hasWatchLink: Bool {
            (deepLinkURL != nil && !(deepLinkURL?.isEmpty ?? true)) ||
            (webURL != nil && !(webURL?.isEmpty ?? true))
        }
    }

    // MARK: - Add Pick

    /// Record a movie as a recent pick. Called when recommendation is displayed.
    /// Year gate: pre-1990 movies are never stored in Recent Picks.
    func addPick(id: String, title: String, posterPath: String?, goodScore: Int,
                 platformDisplayName: String? = nil, deepLinkURL: String? = nil,
                 webURL: String? = nil, year: Int? = nil) {
        // Year gate: reject pre-1990 movies at add time
        if let y = year, y > 0 && y < 1990 { return }

        var picks = getRawPicks()
        picks.removeAll { $0.id == id }
        let pick = RecentPick(
            id: id, title: title, posterPath: posterPath, goodScore: goodScore,
            platformDisplayName: platformDisplayName, deepLinkURL: deepLinkURL,
            webURL: webURL, year: year
        )
        picks.insert(pick, at: 0)
        picks = Array(picks.prefix(maxPicks))
        if let encoded = try? JSONEncoder().encode(picks) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Get Picks

    /// Returns recent picks, most recent first.
    /// Filters out: suppressed movies + pre-1990 movies (purge legacy entries).
    func getPicks() -> [RecentPick] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let picks = try? JSONDecoder().decode([RecentPick].self, from: data) else { return [] }

        let filtered = picks.filter { pick in
            // Purge pre-1990 movies from storage (handles legacy data from before year gate)
            if let y = pick.year, y > 0 && y < 1990 { return false }
            // Suppress rejected/seen movies
            guard let uuid = UUID(uuidString: pick.id) else { return true }
            return !GWSuppressionManager.shared.isSuppressed(movieId: uuid)
        }

        // If any pre-1990 picks were removed, persist the cleaned list immediately
        if filtered.count < picks.count {
            if let encoded = try? JSONEncoder().encode(filtered) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }

        return filtered
    }

    /// Returns ALL stored picks without suppression filtering (for internal storage operations).
    private func getRawPicks() -> [RecentPick] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let picks = try? JSONDecoder().decode([RecentPick].self, from: data) else { return [] }
        return picks
    }

    // MARK: - Clear

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
