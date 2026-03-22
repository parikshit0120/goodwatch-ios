import Foundation
import PostHog

// ============================================
// GWColdStartService — Cold Start Pool Builder
// ============================================
//
// Builds a curated pool of high-quality movies for new users (< 50 interactions
// AND account age < 30 days). The pool is pre-computed on login and cached daily.
//
// Cold start pool rules:
//   - Rating >= 8.0 (progressive relaxation to 7.5 if pool < 20)
//   - Matches user's selected OTT platform(s)
//   - Matches user's selected mood (strict, no fallthrough)
//   - Matches user's selected language
//   - Matches user's selected duration range
//   - Minimum pool size: 20 movies
//   - Progressive relaxation: duration -> OTT -> rating (mood/language NEVER relaxed)
//
// Cache invalidates daily via Calendar.current.isDateInToday().
// ============================================

final class GWColdStartService {
    static let shared = GWColdStartService()
    private init() {}

    // MARK: - Cache State

    /// Cached cold start pool (pre-filtered GWMovie array)
    private(set) var cachedPool: [GWMovie] = []

    /// Whether the pool was built with relaxed filters
    private(set) var wasRelaxed: Bool = false

    /// Relaxation level applied (for PostHog logging)
    private(set) var relaxationLevel: String = "none"

    // MARK: - UserDefaults Keys

    private let poolDateKey = "gw_cold_start_pool_date"

    // MARK: - Public API

    /// Whether a valid cold start pool is cached for today.
    var hasValidPool: Bool {
        guard !cachedPool.isEmpty else { return false }
        guard let storedDate = UserDefaults.standard.object(forKey: poolDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(storedDate)
    }

    /// Build the cold start pool from a raw movie array.
    /// Call on login and when pool is invalidated (new day).
    ///
    /// Parameters:
    ///   - movies: Raw Movie array from Supabase
    ///   - platforms: User's selected OTT platforms (e.g., ["netflix", "prime"])
    ///   - languages: User's preferred languages (e.g., ["english", "hindi"])
    ///   - mood: User's selected mood (e.g., "feel_good")
    ///   - minDuration: Minimum runtime in minutes
    ///   - maxDuration: Maximum runtime in minutes
    func buildPool(
        from movies: [Movie],
        platforms: [String],
        languages: [String],
        mood: String,
        minDuration: Int,
        maxDuration: Int
    ) {
        let allGWMovies = movies
            .filter { $0.poster_path != nil && !($0.poster_path ?? "").isEmpty }
            .filter { $0.is_standup != true }
            .map { GWMovie(from: $0) }

        // Get mood compatible tags for strict mood matching
        let moodMapping = GWMoodConfigService.shared.getMoodMapping(for: mood)
        let moodTags = Set(moodMapping?.compatibleTags ?? [])

        // Step 1: Strict filter — rating >= 8.0, all signals match
        var pool = filterPool(
            movies: allGWMovies,
            platforms: platforms,
            languages: languages,
            moodTags: moodTags,
            minDuration: minDuration,
            maxDuration: maxDuration,
            minRating: 8.0
        )

        relaxationLevel = "none"
        wasRelaxed = false

        // Progressive relaxation if pool < 20
        if pool.count < 20 {
            // Step 1: Loosen duration (0 to 300 min)
            pool = filterPool(
                movies: allGWMovies,
                platforms: platforms,
                languages: languages,
                moodTags: moodTags,
                minDuration: 0,
                maxDuration: 300,
                minRating: 8.0
            )
            relaxationLevel = "duration_relaxed"
            wasRelaxed = true

            if pool.count < 20 {
                // Step 2: Add all OTT platforms (not just user's selection)
                pool = filterPool(
                    movies: allGWMovies,
                    platforms: [],  // Empty = no platform filter
                    languages: languages,
                    moodTags: moodTags,
                    minDuration: 0,
                    maxDuration: 300,
                    minRating: 8.0
                )
                relaxationLevel = "ott_relaxed"

                if pool.count < 20 {
                    // Step 3: Drop rating floor to 7.5
                    pool = filterPool(
                        movies: allGWMovies,
                        platforms: [],
                        languages: languages,
                        moodTags: moodTags,
                        minDuration: 0,
                        maxDuration: 300,
                        minRating: 7.5
                    )
                    relaxationLevel = "rating_relaxed"

                    if pool.count < 20 {
                        // Final fallback: top 20 by rating matching mood + language only
                        pool = allGWMovies
                            .filter { languageMatch(movie: $0, languages: languages) }
                            .filter { moodTags.isEmpty || !Set($0.tags).intersection(moodTags).isEmpty }
                            .sorted { $0.goodscore > $1.goodscore }
                        pool = Array(pool.prefix(20))
                        relaxationLevel = "final_fallback"

                        PostHogSDK.shared.capture("cold_start_pool_exhausted_fallback", properties: [
                            "mood": mood,
                            "language": languages.first ?? "unknown",
                            "final_pool_size": pool.count
                        ])
                    }
                }
            }

            if wasRelaxed && relaxationLevel != "final_fallback" {
                PostHogSDK.shared.capture("cold_start_pool_relaxed", properties: [
                    "relaxation_level": relaxationLevel,
                    "pool_size": pool.count,
                    "mood": mood
                ])
            }
        }

        // Cache the pool
        cachedPool = pool
        UserDefaults.standard.set(Date(), forKey: poolDateKey)

        #if DEBUG
        print("[ColdStart] Built pool: \(pool.count) movies (relaxation=\(relaxationLevel))")
        #endif
    }

    /// Invalidate the cached pool (e.g., on new day or preference change).
    func invalidatePool() {
        cachedPool = []
        UserDefaults.standard.removeObject(forKey: poolDateKey)
    }

    // MARK: - Private Filtering

    private func filterPool(
        movies: [GWMovie],
        platforms: [String],
        languages: [String],
        moodTags: Set<String>,
        minDuration: Int,
        maxDuration: Int,
        minRating: Double
    ) -> [GWMovie] {
        movies.filter { movie in
            // Rating gate
            guard movie.goodscore >= minRating else { return false }

            // Language match (never relaxed)
            guard languageMatch(movie: movie, languages: languages) else { return false }

            // Mood match via tags (never relaxed)
            if !moodTags.isEmpty {
                let movieTags = Set(movie.tags)
                guard !movieTags.intersection(moodTags).isEmpty else { return false }
            }

            // Platform match (relaxed when platforms is empty)
            if !platforms.isEmpty {
                guard platformMatch(movie: movie, platforms: platforms) else { return false }
            }

            // Duration match
            if minDuration > 0 || maxDuration < 300 {
                guard movie.runtime >= minDuration && movie.runtime <= maxDuration else { return false }
            }

            return true
        }
    }

    private func languageMatch(movie: GWMovie, languages: [String]) -> Bool {
        let movieLang = movie.language.lowercased()
        return languages.contains(where: { $0.lowercased() == movieLang })
    }

    private func platformMatch(movie: GWMovie, platforms: [String]) -> Bool {
        let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
        // Fuzzy matching: expand user platform names
        for platform in platforms {
            let expanded = expandPlatformName(platform.lowercased())
            if !moviePlatforms.intersection(expanded).isEmpty {
                return true
            }
        }
        return false
    }

    private func expandPlatformName(_ name: String) -> Set<String> {
        switch name {
        case "netflix":
            return ["netflix", "netflix kids"]
        case "prime", "amazon_prime", "prime_video":
            return ["amazon prime video", "amazon prime video with ads", "amazon video", "prime video"]
        case "jio_hotstar", "jiohotstar", "hotstar":
            return ["jiohotstar", "hotstar", "disney+ hotstar", "jio hotstar"]
        case "apple_tv", "apple_tv_plus":
            return ["apple tv", "apple tv+"]
        case "zee5":
            return ["zee5"]
        case "sony_liv", "sonyliv":
            return ["sony liv", "sonyliv"]
        default:
            return [name]
        }
    }
}
