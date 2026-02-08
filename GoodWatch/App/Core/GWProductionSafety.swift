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
    // PHASE 1A: PROD-Safe Assertions
    // DEBUG → crash, PROD → log + continue
    // ============================================

    /// PROD-safe validation that logs to Supabase instead of crashing.
    /// Returns (isValid, failure) tuple for explicit handling.
    func validateForProduction(
        _ movie: GWMovie,
        profile: GWUserProfileComplete
    ) -> (isValid: Bool, failure: GWValidationFailure?) {
        let result = isValidMovie(movie, profile: profile)

        switch result {
        case .valid:
            return (true, nil)
        case .invalid(let failure):
            // Log to Supabase asynchronously
            Task {
                await logValidationFailureToSupabase(
                    userId: profile.userId,
                    movieId: movie.id,
                    movieTitle: movie.title,
                    failure: failure
                )
            }

            #if DEBUG
            // In DEBUG, crash to catch bugs immediately
            assertionFailure("VALIDATION FAILED: \(failure.description)")
            #endif

            return (false, failure)
        }
    }

    /// PROD-safe language assertion
    func assertLanguageMatchProduction(
        movieLang: String,
        userLangs: [String],
        userId: String,
        movieId: String
    ) {
        if userLangs.isEmpty { return }

        let normalized = movieLang.lowercased()
        let match = userLangs.contains { lang in
            let l = lang.lowercased()
            return normalized.contains(l) ||
                   (l == "english" && normalized == "en") ||
                   (l == "hindi" && normalized == "hi")
        }

        if !match {
            let failure = GWValidationFailure.languageMismatch(
                movieLang: movieLang,
                userLangs: userLangs
            )

            // Log to Supabase
            Task {
                await logValidationFailureToSupabase(
                    userId: userId,
                    movieId: movieId,
                    movieTitle: "unknown",
                    failure: failure
                )
            }

            #if DEBUG
            fatalError("LANGUAGE ASSERTION FAILED: movie '\(movieLang)' not in user languages \(userLangs)")
            #else
            print("🚨 PROD ERROR: Language mismatch - \(failure.description)")
            #endif
        }
    }

    // ============================================
    // PHASE 1B: Controlled Fallback (Explicit)
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

    private func logValidationFailureToSupabase(
        userId: String,
        movieId: String,
        movieTitle: String,
        failure: GWValidationFailure
    ) async {
        guard SupabaseConfig.isConfigured else { return }

        let failureType: String
        var failureDetailsDict: [String: Any] = [:]

        switch failure {
        case .languageMismatch(let movieLang, let userLangs):
            failureType = "language_mismatch"
            failureDetailsDict = ["movie_lang": movieLang, "user_langs": userLangs]
        case .platformMismatch(let moviePlatforms, let userPlatforms):
            failureType = "platform_mismatch"
            failureDetailsDict = ["movie_platforms": moviePlatforms, "user_platforms": userPlatforms]
        case .alreadyInteracted(let id, let reason):
            failureType = "already_interacted"
            failureDetailsDict = ["movie_id": id, "reason": reason]
        case .runtimeOutOfWindow(let runtime, let window):
            failureType = "runtime_out_of_window"
            failureDetailsDict = ["movie_runtime": runtime, "window_min": window.min, "window_max": window.max]
        case .goodscoreBelowThreshold(let score, let threshold):
            failureType = "goodscore_below_threshold"
            failureDetailsDict = ["score": score, "threshold": threshold]
        case .noMatchingTags(let movieTags, let intentTags):
            failureType = "no_matching_tags"
            failureDetailsDict = ["movie_tags": movieTags, "intent_tags": intentTags]
        case .movieUnavailable:
            failureType = "movie_unavailable"
        case .contentTypeMismatch(let expected, let actual):
            failureType = "content_type_mismatch"
            failureDetailsDict = ["expected": expected, "actual": actual ?? "nil"]
        case .qualityGateFailed(let rating, let voteCount):
            failureType = "quality_gate_failed"
            failureDetailsDict = ["rating": rating, "vote_count": voteCount, "min_rating": 6.5, "min_votes": 500]
        }

        do {
            let failureDetailsJSON = try JSONSerialization.data(withJSONObject: failureDetailsDict)
            let failureDetailsString = String(data: failureDetailsJSON, encoding: .utf8) ?? "{}"

            let insertData: [String: Any] = [
                "user_id": userId,
                "movie_id": movieId,
                "movie_title": movieTitle,
                "failure_type": failureType,
                "failure_details": failureDetailsString
            ]

            try await insertToSupabase(table: "validation_failures", data: insertData)
        } catch {
            print("🚨 Failed to log validation failure: \(error)")
        }
    }

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

// MARK: - Supabase Recommendation Logging Extension

extension GWRecommendationEngine {

    /// Log a recommendation to Supabase (MUST be called for every recommendation)
    func logRecommendationToSupabase(
        userId: String,
        movie: GWMovie,
        profile: GWUserProfileComplete,
        candidateCount: Int,
        accepted: Bool? = nil
    ) async {
        guard SupabaseConfig.isConfigured else { return }

        let threshold = gwGoodscoreThreshold(
            mood: profile.mood,
            timeOfDay: GWTimeOfDay.current,
            style: profile.recommendationStyle
        )

        do {
            var insertData: [String: Any] = [
                "user_id": userId,
                "movie_id": movie.id,
                "movie_title": movie.title,
                "goodscore": movie.goodscore,
                "threshold_used": threshold,
                "mood": profile.mood,
                "time_of_day": GWTimeOfDay.current.rawValue,
                "candidate_count": candidateCount,
                "platforms_matched": movie.platforms,
                "language_matched": movie.language,
                "intent_tags_matched": Array(Set(movie.tags).intersection(Set(profile.intentTags)))
            ]

            if let accepted = accepted {
                insertData["accepted"] = accepted
            }

            try await insertToSupabase(table: "recommendation_logs", data: insertData)

            #if DEBUG
            print("📊 Recommendation logged to Supabase: \(movie.title)")
            #endif
        } catch {
            print("🚨 Failed to log recommendation: \(error)")
            // In PROD, this is a critical failure - log but don't crash
            #if DEBUG
            assertionFailure("Recommendation logging failed - this is critical")
            #endif
        }
    }

    /// Update recommendation outcome when user accepts/rejects
    func updateRecommendationOutcome(
        userId: String,
        movieId: String,
        accepted: Bool,
        rejectionReason: String? = nil
    ) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            var updateData: [String: Any] = ["accepted": accepted]
            if let reason = rejectionReason {
                updateData["rejection_reason"] = reason
            }

            // Build URL with filters
            var urlString = "\(SupabaseConfig.url)/rest/v1/recommendation_logs"
            urlString += "?user_id=eq.\(userId)&movie_id=eq.\(movieId)&order=created_at.desc&limit=1"

            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                throw NSError(domain: "SupabaseUpdate", code: -1)
            }

            #if DEBUG
            print("📊 Recommendation outcome updated: \(movieId) -> \(accepted ? "accepted" : "rejected")")
            #endif
        } catch {
            print("🚨 Failed to update recommendation outcome: \(error)")
        }
    }
}
