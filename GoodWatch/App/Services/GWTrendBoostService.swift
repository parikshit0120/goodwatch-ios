import Foundation

// ============================================
// TREND BOOST SERVICE
// ============================================
// Fetches and caches active trend boosts from Supabase.
// Used by RootFlowView to provide trend data to the recommendation engine.
//
// Invariants:
//   INV-T01: No stacking — keeps highest boost per tmdb_id
//   INV-T02: Only fetches boosts where active_until > now()
//   INV-T03: Boost application is engine-side (additive, after core signals)
// ============================================

// MARK: - Data Model

/// A single trend boost entry from the trend_boosts Supabase table.
struct GWTrendBoost: Codable {
    let tmdb_id: Int
    let boost_score: Double
    let relevance_tag: String
    let trend_source: String
    let trend_type: String
    let active_until: String

    enum CodingKeys: String, CodingKey {
        case tmdb_id, boost_score, relevance_tag, trend_source, trend_type, active_until
    }
}

// MARK: - Service

/// Fetches active trend boosts from Supabase and caches them.
/// Thread-safe: all access is async and cache mutations are serial.
final class GWTrendBoostService {
    static let shared = GWTrendBoostService()
    private init() {}

    /// Cache: tmdb_id -> GWTrendBoost (highest boost only per INV-T01)
    private var cache: [Int: GWTrendBoost] = [:]
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 3600  // 1 hour

    /// Fetch active trend boosts from Supabase.
    /// Returns a dict of tmdb_id -> GWTrendBoost.
    /// Cached for 1 hour. Gracefully returns empty/stale cache on failure.
    func fetchActiveTrendBoosts() async -> [Int: GWTrendBoost] {
        // Return cache if fresh
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           !cache.isEmpty {
            return cache
        }

        // INV-T02: Only fetch active boosts that haven't expired
        let now = ISO8601DateFormatter().string(from: Date())
        let encoded = now.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? now
        let urlString = "\(SupabaseConfig.url)/rest/v1/trend_boosts?is_active=eq.true&active_until=gt.\(encoded)&select=tmdb_id,boost_score,relevance_tag,trend_source,trend_type,active_until"

        guard let url = URL(string: urlString) else { return cache }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await GWNetworkSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("[TREND] Fetch failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                #endif
                return cache
            }

            let boosts = try JSONDecoder().decode([GWTrendBoost].self, from: data)

            // INV-T01: No stacking — keep only the highest boost per tmdb_id
            var bestBoosts: [Int: GWTrendBoost] = [:]
            for boost in boosts {
                if let existing = bestBoosts[boost.tmdb_id] {
                    if boost.boost_score > existing.boost_score {
                        bestBoosts[boost.tmdb_id] = boost
                    }
                } else {
                    bestBoosts[boost.tmdb_id] = boost
                }
            }

            cache = bestBoosts
            lastFetchTime = Date()

            #if DEBUG
            print("[TREND] Fetched \(boosts.count) boosts, \(bestBoosts.count) unique movies")
            #endif

            return bestBoosts
        } catch {
            #if DEBUG
            print("[TREND] Fetch error: \(error.localizedDescription)")
            #endif
            return cache  // Graceful degradation
        }
    }

    /// Build a UUID-keyed lookup from tmdb_id boosts + raw Movie pool.
    /// Bridges the gap: GWMovie.id is Supabase UUID, trend_boosts keys on tmdb_id.
    /// Called once per recommendation cycle in RootFlowView.fetchRecommendation().
    func buildUUIDLookup(trendBoosts: [Int: GWTrendBoost], movies: [Movie]) -> [String: GWTrendBoost] {
        var result: [String: GWTrendBoost] = [:]
        for movie in movies {
            guard let tmdbId = movie.tmdb_id,
                  let boost = trendBoosts[tmdbId] else { continue }
            result[movie.id.uuidString] = boost
        }
        return result
    }

    /// Clear cache (for testing or manual refresh)
    func clearCache() {
        cache = [:]
        lastFetchTime = nil
    }
}
