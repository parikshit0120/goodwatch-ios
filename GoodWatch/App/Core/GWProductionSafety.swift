import Foundation

// ============================================
// PRODUCTION SAFETY SWITCHES
// ============================================
//
// FROZEN: GWRecommendationEngine.swift, isValidMovie()
// This file adds PROD-safe wrappers around the frozen logic.
//
// Rules:
// - DEBUG → fatalError (catch bugs early)
// - PROD → log_validation_failure + safe fallback (no crashes)
// ============================================

// MARK: - Fallback Levels (Explicit Logging)

enum GWFallbackLevel: Int, Codable {
    case none = 0           // No fallback needed
    case relaxedTags = 1    // Relaxed intent_tags (same genre family)
    case relaxedRuntime = 2 // Relaxed runtime by +15 min max
    case exhausted = 3      // All fallbacks failed
}

struct GWFallbackLog: Codable {
    let fallbackLevel: GWFallbackLevel
    let userId: String
    let movieId: String?
    let originalProfile: String  // JSON summary
    let relaxedProfile: String   // JSON summary
    let timestamp: Date

    func toJSON() -> [String: Any] {
        [
            "fallback_level": fallbackLevel.rawValue,
            "user_id": userId,
            "movie_id": movieId ?? "nil",
            "original_profile": originalProfile,
            "relaxed_profile": relaxedProfile,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
    }
}

// MARK: - Production-Safe Recommendation Extension

extension GWRecommendationEngine {

    // ============================================
    // Controlled Fallback (Explicit)
    // ============================================

    /// Recommend with controlled fallback if zero valid movies remain.
    /// Fallback rules (strict order):
    /// 1. Keep language + platform fixed (NEVER relax)
    /// 2. Relax intent_tags (same genre family only)
    /// 3. Relax runtime by +15 min max
    func recommendWithFallback(
        from movies: [GWMovie],
        profile: GWUserProfileComplete
    ) -> (output: GWRecommendationOutput, fallbackLevel: GWFallbackLevel, fallbackLog: GWFallbackLog?) {

        // Step 1: Try with original profile
        let originalResult = recommend(from: movies, profile: profile)
        if originalResult.movie != nil {
            return (originalResult, .none, nil)
        }

        // Step 2: Fallback Level 1 - Relax intent_tags (same genre family)
        var relaxedProfile = profile
        relaxedProfile.intentTags = expandToGenreFamily(profile.intentTags)

        let level1Result = recommend(from: movies, profile: relaxedProfile)
        if level1Result.movie != nil {
            let log = createFallbackLog(
                level: .relaxedTags,
                userId: profile.userId,
                movieId: level1Result.movie?.id,
                original: profile,
                relaxed: relaxedProfile
            )
            logFallback(log)
            return (level1Result, .relaxedTags, log)
        }

        // Step 3: Fallback Level 2 - Relax runtime by +15 min
        relaxedProfile.runtimeWindow = GWRuntimeWindow(
            min: max(30, profile.runtimeWindow.min - 15),
            max: min(240, profile.runtimeWindow.max + 15)
        )

        let level2Result = recommend(from: movies, profile: relaxedProfile)
        if level2Result.movie != nil {
            let log = createFallbackLog(
                level: .relaxedRuntime,
                userId: profile.userId,
                movieId: level2Result.movie?.id,
                original: profile,
                relaxed: relaxedProfile
            )
            logFallback(log)
            return (level2Result, .relaxedRuntime, log)
        }

        // Step 4: All fallbacks exhausted
        let log = createFallbackLog(
            level: .exhausted,
            userId: profile.userId,
            movieId: nil,
            original: profile,
            relaxed: relaxedProfile
        )
        logFallback(log)

        return (originalResult, .exhausted, log)
    }

    /// Convenience: recommend with fallback from raw Movie array + content filter
    func recommendWithFallback(
        fromRawMovies movies: [Movie],
        profile: GWUserProfileComplete,
        contentFilter: GWNewUserContentFilter
    ) -> (output: GWRecommendationOutput, fallbackLevel: GWFallbackLevel, fallbackLog: GWFallbackLog?) {
        let gwMovies = movies.map { GWMovie(from: $0) }.filter { !contentFilter.shouldExclude(movie: $0) }
        return recommendWithFallback(from: gwMovies, profile: profile)
    }

    /// Expand intent tags to same genre family
    private func expandToGenreFamily(_ tags: [String]) -> [String] {
        var expanded = Set(tags)

        // Genre families - expand to related tags
        let genreFamilies: [[String]] = [
            // Feel-good family
            ["feel_good", "light", "calm", "rewatchable", "background_friendly"],
            // Intense family
            ["intense", "tense", "high_energy", "full_attention"],
            // Dark family
            ["dark", "heavy", "polarizing", "acquired_taste"],
            // Safe family
            ["safe_bet", "crowd_pleaser", "mainstream"]
        ]

        for family in genreFamilies {
            if tags.contains(where: { family.contains($0) }) {
                // Add all tags from this family
                for tag in family {
                    expanded.insert(tag)
                }
            }
        }

        return Array(expanded)
    }

    private func createFallbackLog(
        level: GWFallbackLevel,
        userId: String,
        movieId: String?,
        original: GWUserProfileComplete,
        relaxed: GWUserProfileComplete
    ) -> GWFallbackLog {
        GWFallbackLog(
            fallbackLevel: level,
            userId: userId,
            movieId: movieId,
            originalProfile: "tags:\(original.intentTags.joined(separator: ",")) runtime:\(original.runtimeWindow.min)-\(original.runtimeWindow.max)",
            relaxedProfile: "tags:\(relaxed.intentTags.joined(separator: ",")) runtime:\(relaxed.runtimeWindow.min)-\(relaxed.runtimeWindow.max)",
            timestamp: Date()
        )
    }

    private func logFallback(_ log: GWFallbackLog) {
        #if DEBUG
        print("⚠️ FALLBACK TRIGGERED: Level \(log.fallbackLevel.rawValue)")
        print("   User: \(log.userId)")
        print("   Original: \(log.originalProfile)")
        print("   Relaxed: \(log.relaxedProfile)")
        #endif

        // Log to Supabase
        Task {
            await logFallbackToSupabase(log)
        }
    }

    // ============================================
    // Supabase Logging Functions (URLSession-based)
    // ============================================

    private func logFallbackToSupabase(_ log: GWFallbackLog) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            let insertData: [String: Any] = [
                "user_id": log.userId,
                "movie_id": log.movieId ?? "00000000-0000-0000-0000-000000000000",
                "movie_title": "FALLBACK_LEVEL_\(log.fallbackLevel.rawValue)",
                "goodscore": 0.0,
                "threshold_used": 0.0,
                "mood": "",
                "time_of_day": "",
                "candidate_count": 0,
                "platforms_matched": [],
                "language_matched": "",
                "intent_tags_matched": []
            ]

            try await insertToSupabase(table: "recommendation_logs", data: insertData)
            print("📊 Fallback logged to Supabase: Level \(log.fallbackLevel.rawValue)")
        } catch {
            print("🚨 Failed to log fallback: \(error)")
        }
    }

    /// Helper to insert data to Supabase using URLSession
    private func insertToSupabase(table: String, data: [String: Any]) async throws {
        let urlString = "\(SupabaseConfig.url)/rest/v1/\(table)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw NSError(domain: "SupabaseInsert", code: -1)
        }
    }
}
