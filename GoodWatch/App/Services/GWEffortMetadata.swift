import Foundation

// ============================================
// GWEffortMetadata — Effort Communication Layer
// ============================================
//
// Provides effort metadata for recommendation cards to communicate
// the work GoodWatch does on behalf of the user.
//
// "Matched from 12,847 titles  .  Saved you ~47 min"
// ============================================

struct GWEffortMetadata {
    /// Total movies in full catalogue (never cold start pool size)
    let moviesAnalyzed: Int

    /// Short match reason for the recommendation
    let matchReasonShort: String

    /// Time saved in minutes (hardcoded to 47)
    let timeSavedMinutes: Int = 47

    /// Formatted effort strip text
    var effortStripText: String {
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: moviesAnalyzed), number: .decimal)
        return "Matched from \(formatted) titles  .  Saved you ~\(timeSavedMinutes) min"
    }
}

// MARK: - Catalogue Count Cache

enum GWCatalogueCount {
    private static let key = "gw_catalogue_count"
    private static let fallback = 12847

    /// Cached catalogue count. Returns fallback (12847) if not yet fetched.
    static var count: Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        return stored > 0 ? stored : fallback
    }

    /// Fire-and-forget fetch of catalogue count from Supabase.
    /// Call once on app launch (non-blocking).
    static func fetchAndCache() {
        Task {
            let urlString = "\(SupabaseConfig.url)/rest/v1/movies?select=count"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("exact", forHTTPHeaderField: "Prefer")

            if let (_, response) = try? await GWNetworkSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               let rangeHeader = httpResponse.allHeaderFields["Content-Range"] as? String,
               let totalStr = rangeHeader.split(separator: "/").last,
               let total = Int(totalStr), total > 0 {
                UserDefaults.standard.set(total, forKey: key)
                #if DEBUG
                print("[GWCatalogue] Cached count: \(total)")
                #endif
            }
        }
    }

    /// Build effort metadata for a recommendation.
    static func buildMetadata(
        mood: String,
        platform: String,
        isNewUser: Bool,
        movieGenre: String
    ) -> GWEffortMetadata {
        let matchReason: String
        if isNewUser {
            matchReason = movieGenre.isEmpty
                ? "One of the highest rated films available now"
                : "One of the highest rated \(movieGenre) films available now"
        } else if !platform.isEmpty && !mood.isEmpty {
            matchReason = "Best \(mood) pick on \(platform) tonight"
        } else {
            matchReason = "Picked for your \(mood) mood"
        }

        return GWEffortMetadata(
            moviesAnalyzed: count,
            matchReasonShort: matchReason
        )
    }
}
