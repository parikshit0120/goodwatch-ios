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
    case relaxedQuality = 3 // Quality relaxation: skip goodscore/tags/quality gate
    case exhausted = 4      // All fallbacks failed
}

struct GWFallbackLog: Codable {
    let fallbackLevel: GWFallbackLevel
    let userId: String
    let movieId: String?
    let originalProfile: String  // JSON summary
    let relaxedProfile: String   // JSON summary
    let timestamp: Date

    // Actual user context for Supabase logging
    let mood: String
    let timeOfDay: String
    let platforms: [String]
    let language: String
    let intentTags: [String]
    let goodscoreThreshold: Double
    let candidateCountBeforeFallback: Int
    let movieGoodscore: Double

    // Adaptive quality gate metadata (INV-R06)
    let adaptiveGateMinRating: Double
    let adaptiveGateMinVotes: Int
    let adaptiveGateWasRelaxed: Bool
    let adaptiveGateReason: String

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

        // Count candidates that pass validation at each level for logging
        let originalValidCount = movies.filter { movie in
            if case .valid = isValidMovie(movie, profile: profile) { return true }
            return false
        }.count

        // Step 1: Try with original profile
        let originalResult = recommend(from: movies, profile: profile)
        if originalResult.movie != nil {
            return (originalResult, .none, nil)
        }

        // Step 2: Fallback Level 1 - Relax mood filter
        var relaxedProfile = profile

        // If using remote mood mapping, expand dimensional ranges by +/-2 and remove anti-tags
        // If using fallback (tag-only), expand intent tags to genre family
        if let originalMapping = profile.moodMapping, originalMapping.version > 0 {
            relaxedProfile.moodMapping = relaxMoodMapping(originalMapping)
        }
        relaxedProfile.intentTags = expandToGenreFamily(profile.intentTags)

        let level1Result = recommend(from: movies, profile: relaxedProfile)
        if level1Result.movie != nil {
            let log = createFallbackLog(
                level: .relaxedTags,
                userId: profile.userId,
                movieId: level1Result.movie?.id,
                original: profile,
                relaxed: relaxedProfile,
                candidateCount: originalValidCount,
                movieGoodscore: level1Result.movie?.goodscore ?? 0
            )
            logFallback(log)
            return (level1Result, .relaxedTags, log)
        }

        // Step 3: Fallback Level 2 - Relax runtime by +15 min + drop recency gate
        relaxedProfile.runtimeWindow = GWRuntimeWindow(
            min: max(30, profile.runtimeWindow.min - 15),
            max: min(240, profile.runtimeWindow.max + 15)
        )
        relaxedProfile.applyRecencyGate = false

        let level2Result = recommend(from: movies, profile: relaxedProfile)
        if level2Result.movie != nil {
            let log = createFallbackLog(
                level: .relaxedRuntime,
                userId: profile.userId,
                movieId: level2Result.movie?.id,
                original: profile,
                relaxed: relaxedProfile,
                candidateCount: originalValidCount,
                movieGoodscore: level2Result.movie?.goodscore ?? 0
            )
            logFallback(log)
            return (level2Result, .relaxedRuntime, log)
        }

        // Step 3B: Fallback Level 3 - Quality relaxation
        // Keep language + platform + availability + interaction-history FIXED
        // Remove: goodscore threshold, mood/tag filter, quality gate
        let level3Result = recommendQualityRelaxed(from: movies, profile: relaxedProfile)
        if level3Result.movie != nil {
            let log = createFallbackLog(
                level: .relaxedQuality,
                userId: profile.userId,
                movieId: level3Result.movie?.id,
                original: profile,
                relaxed: relaxedProfile,
                candidateCount: originalValidCount,
                movieGoodscore: level3Result.movie?.goodscore ?? 0
            )
            logFallback(log)
            return (level3Result, .relaxedQuality, log)
        }

        // Step 4: All fallbacks exhausted
        let log = createFallbackLog(
            level: .exhausted,
            userId: profile.userId,
            movieId: nil,
            original: profile,
            relaxed: relaxedProfile,
            candidateCount: originalValidCount,
            movieGoodscore: 0
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

    // ============================================
    // Level 3: Quality-Relaxed Recommendation
    // ============================================

    /// Level 3 fallback: keeps hard gates (availability, language, platform, interactions,
    /// content type) but drops soft gates (goodscore, tags, quality gate, runtime, recency).
    /// Sorts by goodscore descending, picks from top-10 via weighted random.
    private func recommendQualityRelaxed(
        from movies: [GWMovie],
        profile: GWUserProfileComplete
    ) -> GWRecommendationOutput {
        var candidates: [GWMovie] = []

        for movie in movies {
            let result = isValidMovie(movie, profile: profile)
            switch result {
            case .valid:
                candidates.append(movie)
            case .invalid(let failure):
                switch failure {
                // Hard gates -- always respect
                case .movieUnavailable, .languageMismatch, .platformMismatch, .alreadyInteracted:
                    continue
                // Content type -- respect (movie users get movies, series users get series)
                case .contentTypeMismatch:
                    continue
                // Soft gates -- allow through at Level 3
                case .goodscoreBelowThreshold, .noMatchingTags, .qualityGateFailed,
                     .runtimeOutOfWindow, .recencyGateFailed:
                    candidates.append(movie)
                }
            }
        }

        guard !candidates.isEmpty else {
            return GWRecommendationOutput(movie: nil, stopCondition: .noCandidatePassesValidity)
        }

        // Sort by goodscore descending (best available quality)
        let sorted = candidates.sorted { $0.goodscore > $1.goodscore }

        // Pick from top-10 via weighted random (same temperature as engine)
        let topN = Array(sorted.prefix(10))
        let picked = qualityRelaxedWeightedPick(from: topN)
        return GWRecommendationOutput(movie: picked, stopCondition: nil)
    }

    /// Weighted random pick using goodscore as the weight signal.
    private func qualityRelaxedWeightedPick(from candidates: [GWMovie]) -> GWMovie? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        let temperature = 0.15
        let maxScore = candidates[0].goodscore
        let weights = candidates.map { exp(($0.goodscore - maxScore) / temperature) }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return candidates[0] }

        let roll = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for (i, weight) in weights.enumerated() {
            cumulative += weight
            if roll < cumulative {
                return candidates[i]
            }
        }
        return candidates.last
    }

    /// Relax a mood mapping: expand dimensional ranges by +/-2, remove anti-tags
    private func relaxMoodMapping(_ mapping: GWMoodMapping) -> GWMoodMapping {
        func relaxMin(_ val: Int?) -> Int? {
            guard let v = val else { return nil }
            return max(0, v - 2)
        }
        func relaxMax(_ val: Int?) -> Int? {
            guard let v = val else { return nil }
            return min(10, v + 2)
        }
        return GWMoodMapping(
            moodKey: mapping.moodKey,
            displayName: mapping.displayName,
            targetComfortMin: relaxMin(mapping.targetComfortMin),
            targetComfortMax: relaxMax(mapping.targetComfortMax),
            targetDarknessMin: relaxMin(mapping.targetDarknessMin),
            targetDarknessMax: relaxMax(mapping.targetDarknessMax),
            targetEmotionalIntensityMin: relaxMin(mapping.targetEmotionalIntensityMin),
            targetEmotionalIntensityMax: relaxMax(mapping.targetEmotionalIntensityMax),
            targetEnergyMin: relaxMin(mapping.targetEnergyMin),
            targetEnergyMax: relaxMax(mapping.targetEnergyMax),
            targetComplexityMin: relaxMin(mapping.targetComplexityMin),
            targetComplexityMax: relaxMax(mapping.targetComplexityMax),
            targetRewatchabilityMin: relaxMin(mapping.targetRewatchabilityMin),
            targetRewatchabilityMax: relaxMax(mapping.targetRewatchabilityMax),
            targetHumourMin: relaxMin(mapping.targetHumourMin),
            targetHumourMax: relaxMax(mapping.targetHumourMax),
            targetMentalstimulationMin: relaxMin(mapping.targetMentalstimulationMin),
            targetMentalstimulationMax: relaxMax(mapping.targetMentalstimulationMax),
            idealComfort: mapping.idealComfort,
            idealDarkness: mapping.idealDarkness,
            idealEmotionalIntensity: mapping.idealEmotionalIntensity,
            idealEnergy: mapping.idealEnergy,
            idealComplexity: mapping.idealComplexity,
            idealRewatchability: mapping.idealRewatchability,
            idealHumour: mapping.idealHumour,
            idealMentalstimulation: mapping.idealMentalstimulation,
            compatibleTags: mapping.compatibleTags,
            antiTags: [], // Remove anti-tags at fallback level
            weightComfort: mapping.weightComfort,
            weightDarkness: mapping.weightDarkness,
            weightEmotionalIntensity: mapping.weightEmotionalIntensity,
            weightEnergy: mapping.weightEnergy,
            weightComplexity: mapping.weightComplexity,
            weightRewatchability: mapping.weightRewatchability,
            weightHumour: mapping.weightHumour,
            weightMentalstimulation: mapping.weightMentalstimulation,
            archetypeMovieIds: mapping.archetypeMovieIds,
            version: mapping.version
        )
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
        relaxed: GWUserProfileComplete,
        candidateCount: Int,
        movieGoodscore: Double
    ) -> GWFallbackLog {
        let threshold = gwGoodscoreThreshold(
            mood: original.mood,
            timeOfDay: GWTimeOfDay.current,
            style: original.recommendationStyle
        )
        let gate = lastAdaptiveGate ?? AdaptiveQualityGate(
            minRating: 6.0, minVotes: 200, wasRelaxed: false, reason: "no_gate_computed"
        )
        return GWFallbackLog(
            fallbackLevel: level,
            userId: userId,
            movieId: movieId,
            originalProfile: "tags:\(original.intentTags.joined(separator: ",")) runtime:\(original.runtimeWindow.min)-\(original.runtimeWindow.max)",
            relaxedProfile: "tags:\(relaxed.intentTags.joined(separator: ",")) runtime:\(relaxed.runtimeWindow.min)-\(relaxed.runtimeWindow.max)",
            timestamp: Date(),
            mood: original.mood,
            timeOfDay: GWTimeOfDay.current.rawValue,
            platforms: original.platforms,
            language: original.preferredLanguages.joined(separator: ","),
            intentTags: original.intentTags,
            goodscoreThreshold: threshold,
            candidateCountBeforeFallback: candidateCount,
            movieGoodscore: movieGoodscore,
            adaptiveGateMinRating: gate.minRating,
            adaptiveGateMinVotes: gate.minVotes,
            adaptiveGateWasRelaxed: gate.wasRelaxed,
            adaptiveGateReason: gate.reason
        )
    }

    private func logFallback(_ log: GWFallbackLog) {
        #if DEBUG
        print("[Safety] FALLBACK TRIGGERED: Level \(log.fallbackLevel.rawValue)")
        print("   User: \(log.userId)")
        print("   Original: \(log.originalProfile)")
        print("   Relaxed: \(log.relaxedProfile)")
        print("   Adaptive gate: minRating=\(log.adaptiveGateMinRating), minVotes=\(log.adaptiveGateMinVotes), relaxed=\(log.adaptiveGateWasRelaxed), reason=\(log.adaptiveGateReason)")
        #endif

        // Track fallback event for dashboard analytics
        MetricsService.shared.track(.recommendationFallback, properties: [
            "fallback_level": log.fallbackLevel.rawValue,
            "mood": log.mood,
            "candidate_count": log.candidateCountBeforeFallback,
            "movie_id": log.movieId ?? "none"
        ])

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
                "goodscore": log.movieGoodscore,
                "threshold_used": log.goodscoreThreshold,
                "mood": log.mood,
                "time_of_day": log.timeOfDay,
                "candidate_count": log.candidateCountBeforeFallback,
                "platforms_matched": log.platforms,
                "language_matched": log.language,
                "intent_tags_matched": log.intentTags
            ]

            try await insertToSupabase(table: "recommendation_logs", data: insertData)
            #if DEBUG
            print("Fallback logged to Supabase: Level \(log.fallbackLevel.rawValue) | mood:\(log.mood) | threshold:\(log.goodscoreThreshold) | candidates:\(log.candidateCountBeforeFallback)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to log fallback: \(error)")
            #endif
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
