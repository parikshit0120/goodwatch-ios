import Foundation

// ============================================
// TASTE ENGINE — Per-User Emotional Preference Model
// ============================================
//
// Computes a persistent emotional preference profile for each user
// from their watch_feedback behavioral data. This is the core moat:
// the recommendation engine learns what emotional texture each user
// actually enjoys (not what they SAY they want).
//
// Algorithm:
//   For each of 8 emotional dimensions:
//   1. Gather all watch_feedback for this user
//   2. For each feedback: get movie's emotional_profile score (0-10, normalize 0-1)
//   3. Weight by: satisfaction * (1.5 if would_pick_again else 0.5) * recency_factor
//   4. If felt_* slider exists, blend as direct signal (weight 2x)
//   5. Store weighted average in user_taste_profiles
//
// Confidence thresholds:
//   < 3 feedbacks: DO NOT use taste profile
//   3-9: Blend 50/50 with mood picker
//   10+: Primary signal, mood picker as modifier
//
// When to run:
//   - After every feedback completion (Stage 1 or Stage 2)
//   - On app launch if last_computed > 24 hours ago
// ============================================

// MARK: - Taste Profile Model (mirrors Supabase user_taste_profiles)

struct GWUserTasteProfile: Codable {
    var prefComfort: Double?
    var prefDarkness: Double?
    var prefIntensity: Double?
    var prefEnergy: Double?
    var prefComplexity: Double?
    var prefRewatchability: Double?
    var prefHumour: Double?
    var prefMentalStimulation: Double?

    var weeknightProfile: [String: Double]
    var weekendProfile: [String: Double]
    var lateNightProfile: [String: Double]

    var totalFeedbackCount: Int
    var satisfactionAvg: Double?
    var lastComputedAt: Date?

    enum CodingKeys: String, CodingKey {
        case prefComfort = "pref_comfort"
        case prefDarkness = "pref_darkness"
        case prefIntensity = "pref_intensity"
        case prefEnergy = "pref_energy"
        case prefComplexity = "pref_complexity"
        case prefRewatchability = "pref_rewatchability"
        case prefHumour = "pref_humour"
        case prefMentalStimulation = "pref_mental_stimulation"
        case weeknightProfile = "weeknight_profile"
        case weekendProfile = "weekend_profile"
        case lateNightProfile = "late_night_profile"
        case totalFeedbackCount = "total_feedback_count"
        case satisfactionAvg = "satisfaction_avg"
        case lastComputedAt = "last_computed_at"
    }

    /// Whether the profile has enough data to be used
    var isUsable: Bool { totalFeedbackCount >= 3 }

    /// Confidence level for scoring weight
    var confidenceWeight: Double {
        if totalFeedbackCount < 3 { return 0.0 }
        if totalFeedbackCount < 10 { return 0.5 }
        if totalFeedbackCount < 20 { return 0.8 }
        return 1.0
    }

    // Empty profile
    static let empty = GWUserTasteProfile(
        prefComfort: nil, prefDarkness: nil, prefIntensity: nil,
        prefEnergy: nil, prefComplexity: nil, prefRewatchability: nil,
        prefHumour: nil, prefMentalStimulation: nil,
        weeknightProfile: [:], weekendProfile: [:], lateNightProfile: [:],
        totalFeedbackCount: 0, satisfactionAvg: nil, lastComputedAt: nil
    )
}

// MARK: - Time Context

enum GWTimeContext {
    case weeknight   // Mon-Thu evening
    case weekend     // Fri-Sun
    case lateNight   // After 10 PM any day

    static func current() -> GWTimeContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat

        // Late night always takes precedence
        if hour >= 22 || hour < 5 {
            return .lateNight
        }

        // Weekend: Friday evening, Saturday, Sunday
        if weekday == 1 || weekday == 7 || (weekday == 6 && hour >= 17) {
            return .weekend
        }

        return .weeknight
    }
}

// MARK: - Watch Feedback Entry (from Supabase)

private struct WatchFeedbackEntry: Codable {
    let movieId: Int
    let finished: Bool?
    let satisfaction: Int?
    let wouldPickAgain: Bool?
    let feltComfort: Int?
    let feltIntensity: Int?
    let feltEnergy: Int?
    let feltHumour: Int?
    let moodAfter: String?
    let timeOfDay: String?
    let dayOfWeek: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case movieId = "movie_id"
        case finished
        case satisfaction
        case wouldPickAgain = "would_pick_again"
        case feltComfort = "felt_comfort"
        case feltIntensity = "felt_intensity"
        case feltEnergy = "felt_energy"
        case feltHumour = "felt_humour"
        case moodAfter = "mood_after"
        case timeOfDay = "time_of_day"
        case dayOfWeek = "day_of_week"
        case createdAt = "created_at"
    }
}

// MARK: - Movie Profile Snapshot (minimal for taste computation)

private struct MovieProfileSnapshot: Codable {
    let id: Int
    let emotionalProfile: EmotionalProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case emotionalProfile = "emotional_profile"
    }
}

// MARK: - Taste Engine

final class GWTasteEngine {
    static let shared = GWTasteEngine()
    private init() {}

    // Cache the profile in memory
    private var cachedProfile: GWUserTasteProfile?
    private var cachedUserId: String?

    /// Get the cached taste profile (or nil if not loaded)
    func getCachedProfile(userId: String) -> GWUserTasteProfile? {
        if cachedUserId == userId {
            return cachedProfile
        }
        return nil
    }

    /// Recompute taste profile if needed (stale > 24h or never computed)
    func recomputeIfNeeded(userId: String) async {
        // Check if we have a recent computation
        if let cached = cachedProfile, cachedUserId == userId,
           let lastComputed = cached.lastComputedAt,
           Date().timeIntervalSince(lastComputed) < 24 * 3600 {
            return // Still fresh
        }

        await recompute(userId: userId)
    }

    /// Force recompute (called after every feedback submission)
    func recompute(userId: String) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            // 1. Fetch all watch_feedback for this user
            let feedbacks = try await fetchFeedbacks(userId: userId)

            guard !feedbacks.isEmpty else {
                cachedProfile = .empty
                cachedUserId = userId
                return
            }

            // 2. Fetch movie emotional profiles for all feedback movies
            let movieIds = feedbacks.map { $0.movieId }
            let movieProfiles = try await fetchMovieProfiles(movieIds: movieIds)

            // 3. Compute taste profile
            let profile = computeProfile(feedbacks: feedbacks, movieProfiles: movieProfiles)

            // 4. Upload to Supabase (fire-and-forget)
            await uploadProfile(userId: userId, profile: profile)

            // 5. Cache
            cachedProfile = profile
            cachedUserId = userId

            #if DEBUG
            print("GWTasteEngine: Recomputed profile for \(userId). Feedbacks: \(profile.totalFeedbackCount), comfort: \(profile.prefComfort ?? -1)")
            #endif
        } catch {
            #if DEBUG
            print("GWTasteEngine: Recompute error: \(error)")
            #endif
        }
    }

    // MARK: - Core Algorithm

    private func computeProfile(
        feedbacks: [WatchFeedbackEntry],
        movieProfiles: [Int: EmotionalProfile]
    ) -> GWUserTasteProfile {
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Accumulate weighted scores per dimension
        var dimensionAccumulators: [String: (weightedSum: Double, totalWeight: Double)] = [:]
        let dimensions = ["comfort", "darkness", "intensity", "energy", "complexity", "rewatchability", "humour", "mentalStimulation"]
        for dim in dimensions {
            dimensionAccumulators[dim] = (0, 0)
        }

        // Contextual accumulators
        var weeknightAccum: [String: (weightedSum: Double, totalWeight: Double)] = [:]
        var weekendAccum: [String: (weightedSum: Double, totalWeight: Double)] = [:]
        var lateNightAccum: [String: (weightedSum: Double, totalWeight: Double)] = [:]
        for dim in dimensions {
            weeknightAccum[dim] = (0, 0)
            weekendAccum[dim] = (0, 0)
            lateNightAccum[dim] = (0, 0)
        }

        var satisfactionSum: Double = 0
        var satisfactionCount: Int = 0

        for feedback in feedbacks {
            guard let movieProfile = movieProfiles[feedback.movieId] else { continue }

            // Base weight from satisfaction
            let satisfactionNorm: Double
            if let sat = feedback.satisfaction {
                satisfactionNorm = Double(sat) / 5.0
                satisfactionSum += Double(sat)
                satisfactionCount += 1
            } else {
                // No satisfaction rating — use mood_after as proxy
                switch feedback.moodAfter {
                case "better": satisfactionNorm = 0.8
                case "same": satisfactionNorm = 0.6
                case "worse": satisfactionNorm = 0.3
                default: satisfactionNorm = 0.5
                }
            }

            // Would-pick-again multiplier
            let pickMultiplier: Double
            if let pick = feedback.wouldPickAgain {
                pickMultiplier = pick ? 1.5 : 0.5
            } else {
                pickMultiplier = 1.0
            }

            // Recency factor
            var recencyFactor: Double = 0.5
            if let dateStr = feedback.createdAt {
                // Try both formats
                let altFormatter = ISO8601DateFormatter()
                altFormatter.formatOptions = [.withInternetDateTime]

                if let date = dateFormatter.date(from: dateStr) ?? altFormatter.date(from: dateStr) {
                    let daysSince = now.timeIntervalSince(date) / (24 * 3600)
                    if daysSince <= 7 { recencyFactor = 1.0 }
                    else if daysSince <= 30 { recencyFactor = 0.8 }
                    else { recencyFactor = 0.5 }
                }
            }

            let baseWeight = satisfactionNorm * pickMultiplier * recencyFactor

            // Map movie emotional profile to dimensions
            let movieDimValues: [String: Double] = [
                "comfort": Double(movieProfile.comfort ?? 5) / 10.0,
                "darkness": Double(movieProfile.darkness ?? 5) / 10.0,
                "intensity": Double(movieProfile.emotionalIntensity ?? 5) / 10.0,
                "energy": Double(movieProfile.energy ?? 5) / 10.0,
                "complexity": Double(movieProfile.complexity ?? 5) / 10.0,
                "rewatchability": Double(movieProfile.rewatchability ?? 5) / 10.0,
                "humour": Double(movieProfile.humour ?? 5) / 10.0,
                "mentalStimulation": Double(movieProfile.mentalStimulation ?? 5) / 10.0,
            ]

            // Map felt_ sliders to direct signals (weight 2x)
            let feltSignals: [String: Double?] = [
                "comfort": feedback.feltComfort.map { Double($0) / 5.0 },
                "intensity": feedback.feltIntensity.map { Double($0) / 5.0 },
                "energy": feedback.feltEnergy.map { Double($0) / 5.0 },
                "humour": feedback.feltHumour.map { Double($0) / 5.0 },
            ]

            // Accumulate each dimension
            for dim in dimensions {
                guard let movieVal = movieDimValues[dim] else { continue }
                var (wSum, tWeight) = dimensionAccumulators[dim]!

                // Movie profile signal
                wSum += movieVal * baseWeight
                tWeight += baseWeight

                // Direct felt_ signal (2x weight)
                if let feltVal = feltSignals[dim] ?? nil {
                    let feltWeight = baseWeight * 2.0
                    wSum += feltVal * feltWeight
                    tWeight += feltWeight
                }

                dimensionAccumulators[dim] = (wSum, tWeight)
            }

            // Contextual accumulation
            let context = classifyContext(timeOfDay: feedback.timeOfDay, dayOfWeek: feedback.dayOfWeek)
            var contextAccum: UnsafeMutablePointer<[String: (Double, Double)]>? = nil

            switch context {
            case .weeknight:
                for dim in dimensions {
                    guard let movieVal = movieDimValues[dim] else { continue }
                    var (wSum, tWeight) = weeknightAccum[dim]!
                    wSum += movieVal * baseWeight
                    tWeight += baseWeight
                    weeknightAccum[dim] = (wSum, tWeight)
                }
            case .weekend:
                for dim in dimensions {
                    guard let movieVal = movieDimValues[dim] else { continue }
                    var (wSum, tWeight) = weekendAccum[dim]!
                    wSum += movieVal * baseWeight
                    tWeight += baseWeight
                    weekendAccum[dim] = (wSum, tWeight)
                }
            case .lateNight:
                for dim in dimensions {
                    guard let movieVal = movieDimValues[dim] else { continue }
                    var (wSum, tWeight) = lateNightAccum[dim]!
                    wSum += movieVal * baseWeight
                    tWeight += baseWeight
                    lateNightAccum[dim] = (wSum, tWeight)
                }
            }
            _ = contextAccum // suppress unused warning
        }

        // Compute final preferences
        func computePref(_ dim: String) -> Double? {
            let (wSum, tWeight) = dimensionAccumulators[dim]!
            guard tWeight > 0 else { return nil }
            return wSum / tWeight
        }

        func contextualProfile(_ accum: [String: (Double, Double)]) -> [String: Double] {
            var result: [String: Double] = [:]
            // Only populate if >= 3 data points (count entries with weight > 0)
            let dataPoints = accum.values.filter { $0.1 > 0 }.count
            guard dataPoints >= 3 else { return result }
            for (dim, (wSum, tWeight)) in accum {
                if tWeight > 0 {
                    result[dim] = wSum / tWeight
                }
            }
            return result
        }

        return GWUserTasteProfile(
            prefComfort: computePref("comfort"),
            prefDarkness: computePref("darkness"),
            prefIntensity: computePref("intensity"),
            prefEnergy: computePref("energy"),
            prefComplexity: computePref("complexity"),
            prefRewatchability: computePref("rewatchability"),
            prefHumour: computePref("humour"),
            prefMentalStimulation: computePref("mentalStimulation"),
            weeknightProfile: contextualProfile(weeknightAccum),
            weekendProfile: contextualProfile(weekendAccum),
            lateNightProfile: contextualProfile(lateNightAccum),
            totalFeedbackCount: feedbacks.count,
            satisfactionAvg: satisfactionCount > 0 ? satisfactionSum / Double(satisfactionCount) : nil,
            lastComputedAt: Date()
        )
    }

    private func classifyContext(timeOfDay: String?, dayOfWeek: Int?) -> GWTimeContext {
        // Late night
        if timeOfDay == "late_night" || timeOfDay == "night" {
            return .lateNight
        }

        // Weekend: 0=Sunday, 5=Friday (evening), 6=Saturday
        if let dow = dayOfWeek {
            if dow == 0 || dow == 6 || (dow == 5 && (timeOfDay == "evening" || timeOfDay == "night")) {
                return .weekend
            }
        }

        return .weeknight
    }

    // MARK: - Supabase Fetch

    private func fetchFeedbacks(userId: String) async throws -> [WatchFeedbackEntry] {
        let urlString = "\(SupabaseConfig.url)/rest/v1/watch_feedback?user_id=eq.\(userId)&order=created_at.desc&limit=100"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        return try JSONDecoder().decode([WatchFeedbackEntry].self, from: data)
    }

    private func fetchMovieProfiles(movieIds: [Int]) async throws -> [Int: EmotionalProfile] {
        guard !movieIds.isEmpty else { return [:] }

        // Fetch in batches of 50
        var result: [Int: EmotionalProfile] = [:]

        for batch in movieIds.chunked(into: 50) {
            let idsString = batch.map { String($0) }.joined(separator: ",")
            let urlString = "\(SupabaseConfig.url)/rest/v1/movies?id=in.(\(idsString))&select=id,emotional_profile"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                continue
            }

            if let movies = try? JSONDecoder().decode([MovieProfileSnapshot].self, from: data) {
                for movie in movies {
                    if let ep = movie.emotionalProfile {
                        result[movie.id] = ep
                    }
                }
            }
        }

        return result
    }

    // MARK: - Supabase Upload

    private func uploadProfile(userId: String, profile: GWUserTasteProfile) async {
        let urlString = "\(SupabaseConfig.url)/rest/v1/user_taste_profiles?on_conflict=user_id"
        guard let url = URL(string: urlString) else { return }

        var body: [String: Any] = [
            "user_id": userId,
            "total_feedback_count": profile.totalFeedbackCount,
            "last_computed_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ]

        if let v = profile.prefComfort { body["pref_comfort"] = v }
        if let v = profile.prefDarkness { body["pref_darkness"] = v }
        if let v = profile.prefIntensity { body["pref_intensity"] = v }
        if let v = profile.prefEnergy { body["pref_energy"] = v }
        if let v = profile.prefComplexity { body["pref_complexity"] = v }
        if let v = profile.prefRewatchability { body["pref_rewatchability"] = v }
        if let v = profile.prefHumour { body["pref_humour"] = v }
        if let v = profile.prefMentalStimulation { body["pref_mental_stimulation"] = v }
        if let v = profile.satisfactionAvg { body["satisfaction_avg"] = v }

        if !profile.weeknightProfile.isEmpty {
            body["weeknight_profile"] = profile.weeknightProfile
        }
        if !profile.weekendProfile.isEmpty {
            body["weekend_profile"] = profile.weekendProfile
        }
        if !profile.lateNightProfile.isEmpty {
            body["late_night_profile"] = profile.lateNightProfile
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            let (_, response) = try await URLSession.shared.data(for: request)
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("GWTasteEngine: Upload status \(httpResponse.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("GWTasteEngine: Upload error: \(error)")
            #endif
        }
    }
}

// MARK: - Taste Score Computation (for GWRecommendationEngine integration)

extension GWTasteEngine {

    /// Compute taste alignment score for a movie against user's learned preferences.
    /// Returns 0-1 where 0.5 = neutral (no taste data or neutral match).
    /// Per INV-L06: max 15% weight in overall scoring formula.
    func computeTasteScore(
        movieProfile: EmotionalProfile?,
        tasteProfile: GWUserTasteProfile?,
        context: GWTimeContext
    ) -> Double {
        guard let taste = tasteProfile, taste.isUsable,
              let movie = movieProfile else {
            return 0.5  // Neutral: no effect on scoring
        }

        // Pick contextual or global prefs
        let contextPrefs: [String: Double]
        switch context {
        case .weeknight: contextPrefs = taste.weeknightProfile
        case .weekend: contextPrefs = taste.weekendProfile
        case .lateNight: contextPrefs = taste.lateNightProfile
        }

        // Get preference for each dimension (contextual if available, else global)
        let prefComfort = contextPrefs["comfort"] ?? taste.prefComfort ?? 0.5
        let prefDarkness = contextPrefs["darkness"] ?? taste.prefDarkness ?? 0.5
        let prefIntensity = contextPrefs["intensity"] ?? taste.prefIntensity ?? 0.5
        let prefEnergy = contextPrefs["energy"] ?? taste.prefEnergy ?? 0.5
        let prefComplexity = contextPrefs["complexity"] ?? taste.prefComplexity ?? 0.5
        let prefRewatchability = contextPrefs["rewatchability"] ?? taste.prefRewatchability ?? 0.5
        let prefHumour = contextPrefs["humour"] ?? taste.prefHumour ?? 0.5
        let prefMentalStim = contextPrefs["mentalStimulation"] ?? taste.prefMentalStimulation ?? 0.5

        // Movie dimension values (0-10 normalized to 0-1)
        let movieDims: [(movie: Double, pref: Double)] = [
            (Double(movie.comfort ?? 5) / 10.0, prefComfort),
            (Double(movie.darkness ?? 5) / 10.0, prefDarkness),
            (Double(movie.emotionalIntensity ?? 5) / 10.0, prefIntensity),
            (Double(movie.energy ?? 5) / 10.0, prefEnergy),
            (Double(movie.complexity ?? 5) / 10.0, prefComplexity),
            (Double(movie.rewatchability ?? 5) / 10.0, prefRewatchability),
            (Double(movie.humour ?? 5) / 10.0, prefHumour),
            (Double(movie.mentalStimulation ?? 5) / 10.0, prefMentalStim),
        ]

        // Mean alignment: 1.0 = perfect match, 0.0 = worst match
        let totalDistance = movieDims.reduce(0.0) { $0 + abs($1.movie - $1.pref) }
        let maxDistance: Double = 8.0  // 8 dimensions * max delta 1.0
        let alignment = 1.0 - (totalDistance / maxDistance)

        // Scale by confidence (more feedback = more trust)
        let confidence = min(Double(taste.totalFeedbackCount) / 20.0, 1.0)

        // Return 0-1 score: 0.5 = neutral, >0.5 = good match, <0.5 = poor match
        return 0.5 + (alignment - 0.5) * confidence
    }
}

// MARK: - Array Chunking Helper

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
