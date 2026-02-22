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

        /// Poster URL for display. Handles both full URLs and TMDB paths.
        var posterURL: String? {
            guard let path = posterPath, !path.isEmpty else { return nil }
            if path.hasPrefix("http") { return path }
            return "https://image.tmdb.org/t/p/w185\(path)"
        }
    }

    // MARK: - Add Pick

    /// Record a movie as a recent pick. Called when recommendation is displayed.
    func addPick(id: String, title: String, posterPath: String?, goodScore: Int) {
        var picks = getPicks()
        picks.removeAll { $0.id == id }
        picks.insert(RecentPick(id: id, title: title, posterPath: posterPath, goodScore: goodScore), at: 0)
        picks = Array(picks.prefix(maxPicks))
        if let encoded = try? JSONEncoder().encode(picks) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Get Picks

    /// Returns recent picks, most recent first.
    func getPicks() -> [RecentPick] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let picks = try? JSONDecoder().decode([RecentPick].self, from: data) else { return [] }
        return picks
    }

    // MARK: - Clear

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
