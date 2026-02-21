import Foundation

// ==========================================
// GOODWATCH SPEC - SECTIONS 0-5
// IMMUTABLE - DO NOT MODIFY
// ==========================================

// MARK: - Section 3: Tag Taxonomy (LOCKED)

enum CognitiveLoad: String, Codable, CaseIterable {
    case light
    case medium
    case heavy
}

enum EmotionalOutcome: String, Codable, CaseIterable {
    case feel_good
    case uplifting
    case dark
    case disturbing
    case bittersweet
}

enum EnergyLevel: String, Codable, CaseIterable {
    case calm
    case tense
    case high_energy
}

enum AttentionLevel: String, Codable, CaseIterable {
    case background_friendly
    case full_attention
    case rewatchable
}

enum RegretRisk: String, Codable, CaseIterable {
    case safe_bet
    case polarizing
    case acquired_taste
}

// All valid tags combined
struct TagTaxonomy {
    static let allTags: Set<String> = {
        var tags = Set<String>()
        CognitiveLoad.allCases.forEach { tags.insert($0.rawValue) }
        EmotionalOutcome.allCases.forEach { tags.insert($0.rawValue) }
        EnergyLevel.allCases.forEach { tags.insert($0.rawValue) }
        AttentionLevel.allCases.forEach { tags.insert($0.rawValue) }
        RegretRisk.allCases.forEach { tags.insert($0.rawValue) }
        return tags
    }()

    static func isValidTag(_ tag: String) -> Bool {
        allTags.contains(tag)
    }
}

// MARK: - Section 2: Data Models (AUTHORITATIVE)

struct GWMovie: Identifiable, Codable {
    let id: String
    let title: String
    let year: Int
    let runtime: Int
    let language: String
    let platforms: [String]
    let poster_url: String?
    let overview: String?
    let genres: [String]
    let tags: [String]
    let goodscore: Double
    let composite_score: Double  // Combined quality score (0-100 scale), 0 if unavailable
    let voteCount: Int        // QUALITY GATE: Must be >= 500 for recommendations
    let available: Bool
    let contentType: String?  // "movie" or "series"
    let emotionalProfile: EmotionalProfile?  // Raw profile for taste graph scoring

    // MARK: - Tiered Quality Gates (Trust-Based)
    // Quality requirements INCREASE for new users, RELAX as trust builds

    /// Tiered quality gate configuration based on user's accept count
    struct QualityGate {
        let minRating: Double
        let minVotes: Int
        let label: String

        /// Get quality gates based on user's watch history
        /// Relaxed thresholds to ensure good catalog coverage while maintaining quality
        /// With 22k+ titles, we can be selective but not too restrictive
        static func forAcceptCount(_ acceptCount: Int) -> QualityGate {
            if acceptCount == 0 {
                // FIRST-TIME: Good quality content (relaxed from 7.5/2000)
                return QualityGate(minRating: 6.8, minVotes: 500, label: "Highly rated")
            } else if acceptCount <= 3 {
                // EARLY TRUST: Solid picks
                return QualityGate(minRating: 6.5, minVotes: 400, label: "Crowd favorite")
            } else if acceptCount <= 10 {
                // BUILDING RELATIONSHIP
                return QualityGate(minRating: 6.2, minVotes: 300, label: "Strong pick")
            } else {
                // TRUSTED USER: Can explore deeper catalog
                return QualityGate(minRating: 6.0, minVotes: 200, label: "Good match")
            }
        }

        /// Default gate for backwards compatibility (use for trusted users)
        static let `default` = QualityGate(minRating: 6.0, minVotes: 200, label: "Good match")

        /// Gate for first-time users (relaxed)
        static let firstTime = QualityGate(minRating: 6.8, minVotes: 500, label: "Highly rated")
    }

    // Legacy constants for backwards compatibility (relaxed for better catalog coverage)
    static let minVoteCount: Int = 200        // Absolute floor (trusted users)
    static let minRating: Double = 6.0        // Absolute floor (trusted users)

    /// Check if this content is a series
    var isSeries: Bool {
        contentType?.lowercased() == "series" || contentType?.lowercased() == "tv"
    }

    /// Check if this content is a movie
    var isMovie: Bool {
        contentType?.lowercased() == "movie" || contentType == nil
    }

    /// Check if this movie passes quality gates for a given user tier
    /// Use `passesQualityGates(for:)` for tiered checking
    var passesQualityGates: Bool {
        // Default: use the most lenient (trusted user) gates
        voteCount >= Self.minVoteCount && goodscore >= Self.minRating
    }

    /// Check if this movie passes tiered quality gates based on user's accept count
    func passesQualityGates(forAcceptCount acceptCount: Int) -> Bool {
        let gate = QualityGate.forAcceptCount(acceptCount)
        return voteCount >= gate.minVotes && goodscore >= gate.minRating
    }

    /// Get the quality label for this movie given user's trust level
    func qualityLabel(forAcceptCount acceptCount: Int) -> String? {
        let gate = QualityGate.forAcceptCount(acceptCount)
        guard passesQualityGates(forAcceptCount: acceptCount) else { return nil }
        return gate.label
    }

    // Convert from existing Movie model
    // CRITICAL: GoodScore calculation respects source ratings
    init(from movie: Movie) {
        self.id = movie.id.uuidString
        self.title = movie.title
        self.year = movie.year ?? 2020
        self.runtime = movie.runtimeMinutes
        self.language = movie.original_language ?? "en"
        self.platforms = movie.platformNames
        self.poster_url = movie.posterURL
        self.overview = movie.overview
        self.genres = movie.genreNames
        self.tags = GWMovie.deriveTags(from: movie)

        // GOODSCORE CALCULATION:
        // Prefer enriched composite_score (multi-source weighted average),
        // then fall back to IMDb rating, then TMDB vote_average.
        // Rating stored on 0-10 scale; normalization to 0-100 happens at display time.
        let sourceRating = movie.composite_score ?? movie.imdb_rating ?? movie.vote_average ?? 0.0
        self.goodscore = sourceRating

        // Composite score on 0-100 scale for display/sorting.
        // If enriched composite_score exists, use it * 10.
        // Otherwise blend IMDb + TMDB if both exist.
        if let cs = movie.composite_score, cs > 0 {
            self.composite_score = cs * 10
        } else if let imdb = movie.imdb_rating, let tmdb = movie.vote_average, imdb > 0 && tmdb > 0 {
            self.composite_score = ((imdb * 0.75) + (tmdb * 0.25)) * 10
        } else {
            self.composite_score = sourceRating * 10
        }

        // Vote count for quality gate validation
        self.voteCount = movie.imdb_votes ?? movie.vote_count ?? 0

        self.available = movie.isAvailable
        self.contentType = movie.content_type
        self.emotionalProfile = movie.emotional_profile
    }

    // Derive tags from emotional_profile
    // CRITICAL: Movies WITHOUT emotional_profile data should NOT get "safe_bet" tag
    // Only movies with verified high ratings AND emotional data can be "safe_bet"
    private static func deriveTags(from movie: Movie) -> [String] {
        var tags: [String] = []

        guard let ep = movie.emotional_profile else {
            // NO emotional profile = we don't know if it's safe
            // Use "polarizing" instead of "safe_bet" for unknown content
            // This prevents garbage from matching "Surprise me" intent
            return ["medium", "polarizing", "full_attention"]
        }

        // Cognitive Load
        let complexity = ep.complexity ?? 5
        if complexity <= 3 {
            tags.append(CognitiveLoad.light.rawValue)
        } else if complexity <= 6 {
            tags.append(CognitiveLoad.medium.rawValue)
        } else {
            tags.append(CognitiveLoad.heavy.rawValue)
        }

        // Emotional Outcome
        let darkness = ep.darkness ?? 5
        let comfort = ep.comfort ?? 5
        if darkness >= 7 {
            tags.append(EmotionalOutcome.dark.rawValue)
        } else if comfort >= 7 {
            tags.append(EmotionalOutcome.feel_good.rawValue)
        } else if comfort >= 5 && darkness <= 4 {
            tags.append(EmotionalOutcome.uplifting.rawValue)
        } else {
            tags.append(EmotionalOutcome.bittersweet.rawValue)
        }

        // Energy
        let energy = ep.energy ?? 5
        if energy <= 3 {
            tags.append(EnergyLevel.calm.rawValue)
        } else if energy >= 7 {
            tags.append(EnergyLevel.high_energy.rawValue)
        } else {
            tags.append(EnergyLevel.tense.rawValue)
        }

        // Attention
        let mentalStim = ep.mentalStimulation ?? 5
        if mentalStim <= 3 {
            tags.append(AttentionLevel.background_friendly.rawValue)
        } else if (ep.rewatchability ?? 5) >= 7 {
            tags.append(AttentionLevel.rewatchable.rawValue)
        } else {
            tags.append(AttentionLevel.full_attention.rawValue)
        }

        // Regret Risk (based on rating variance and intensity)
        let intensity = ep.emotionalIntensity ?? 5
        let rating = movie.imdb_rating ?? movie.vote_average ?? 7.0
        if rating >= 7.5 && intensity <= 6 {
            tags.append(RegretRisk.safe_bet.rawValue)
        } else if intensity >= 8 || darkness >= 8 {
            tags.append(RegretRisk.acquired_taste.rawValue)
        } else {
            tags.append(RegretRisk.polarizing.rawValue)
        }

        return tags
    }
}

struct GWValidationProfile {
    let id: String
    var preferred_languages: [String]
    var platforms: [String]
    var runtime_window: (min: Int, max: Int)
    var risk_tolerance: RiskTolerance

    enum RiskTolerance: String, Codable {
        case low
        case medium
        case high
    }

    init(id: String, preferred_languages: [String], platforms: [String], runtime_window: (Int, Int), risk_tolerance: RiskTolerance) {
        self.id = id
        self.preferred_languages = preferred_languages
        self.platforms = platforms
        self.runtime_window = runtime_window
        self.risk_tolerance = risk_tolerance
    }
}

struct GWIntent: Codable {
    var mood: String
    var energy: EnergyLevel
    var cognitive_load: CognitiveLoad
    var intent_tags: [String]

    static let `default` = GWIntent(
        mood: "neutral",
        energy: .calm,
        cognitive_load: .light,
        intent_tags: ["safe_bet", "feel_good"]
    )
}

struct GWSpecInteraction: Codable {
    let user_id: String
    let movie_id: String
    let action: SpecInteractionAction
    let timestamp: String

    enum SpecInteractionAction: String, Codable {
        case watch_now
        case not_tonight
        case abandoned
        case completed
        case show_me_another  // Weak signal: user wasn't excited but didn't actively reject
        case implicit_skip    // Multi-pick: user chose a different card (same delta as show_me_another)
    }

    init(userId: String, movieId: String, action: SpecInteractionAction) {
        self.user_id = userId
        self.movie_id = movieId
        self.action = action
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Section 4: GoodScore Threshold Logic (NON-NEGOTIABLE)

enum TimeOfDay: String {
    case morning
    case afternoon
    case evening
    case late_night

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .late_night
        }
    }
}

func goodscoreThreshold(mood: String, timeOfDay: TimeOfDay) -> Double {
    if timeOfDay == .late_night { return 85 }
    if mood == "tired" { return 88 }
    if mood == "adventurous" { return 75 }
    return 80
}

// MARK: - Section 5: Scoring (Secondary Filter Only)

func computeScore(movie: GWMovie, intent: GWIntent) -> Double {
    let movieTags = Set(movie.tags)
    let intentTags = Set(intent.intent_tags)

    // Tag alignment
    let intersection = movieTags.intersection(intentTags)
    let tagAlignment = intentTags.isEmpty ? 0.0 : Double(intersection.count) / Double(intentTags.count)

    // Regret safety
    let regretSafety: Double
    if movieTags.contains(RegretRisk.safe_bet.rawValue) {
        regretSafety = 1.0
    } else if movieTags.contains(RegretRisk.polarizing.rawValue) {
        regretSafety = 0.4
    } else {
        regretSafety = 0.6
    }

    // Final score
    return (tagAlignment * 0.6) + (regretSafety * 0.4)
}

// MARK: - Section 1: Movie Validity (Absolute Gate)

enum ValidationFailure: String {
    case language_mismatch = "Language not in user preferences"
    case platform_mismatch = "No matching platform"
    case already_interacted = "Movie already seen/rejected"
    case runtime_out_of_window = "Runtime outside user window"
    case goodscore_below_threshold = "GoodScore below threshold"
    case no_matching_tags = "No matching intent tags"
}

struct MovieValidator {
    let profile: GWValidationProfile
    let intent: GWIntent
    let excludedMovieIds: Set<String>

    /// Validates a movie against ALL 6 rules
    /// Returns nil if valid, or the failure reason if invalid
    func validate(_ movie: GWMovie) -> ValidationFailure? {
        // Rule 1: movie.language ∈ user.preferred_languages
        let movieLang = movie.language.lowercased()
        let userLangs = profile.preferred_languages.map { $0.lowercased() }
        let langMatch = userLangs.contains { lang in
            movieLang.contains(lang) ||
            (lang == "english" && movieLang == "en") ||
            (lang == "hindi" && movieLang == "hi")
        }
        if !langMatch && !userLangs.isEmpty {
            return .language_mismatch
        }

        // Rule 2: movie.platforms ∩ user.platforms ≠ ∅
        let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
        let userPlatforms = Set(profile.platforms.map { $0.lowercased() })
        if moviePlatforms.intersection(userPlatforms).isEmpty && !userPlatforms.isEmpty {
            return .platform_mismatch
        }

        // Rule 3: movie.id ∉ {seen, not_tonight, abandoned}
        if excludedMovieIds.contains(movie.id) {
            return .already_interacted
        }

        // Rule 4: movie.runtime ∈ user.runtime_window
        if movie.runtime < profile.runtime_window.min || movie.runtime > profile.runtime_window.max {
            return .runtime_out_of_window
        }

        // Rule 5: movie.goodscore ≥ threshold(user.mood, time_of_day)
        let threshold = goodscoreThreshold(mood: intent.mood, timeOfDay: TimeOfDay.current)
        // Convert goodscore to 0-100 scale if needed
        let normalizedScore = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
        if normalizedScore < threshold {
            return .goodscore_below_threshold
        }

        // Rule 6: movie.tags ∩ user.intent_tags ≠ ∅
        let movieTags = Set(movie.tags)
        let intentTags = Set(intent.intent_tags)
        if movieTags.intersection(intentTags).isEmpty && !intentTags.isEmpty {
            return .no_matching_tags
        }

        return nil // Valid
    }

    /// Returns first valid movie from list, logging failures
    func selectValidMovie(from movies: [GWMovie]) -> GWMovie? {
        for movie in movies {
            if let failure = validate(movie) {
                #if DEBUG
                print("❌ \(movie.title): \(failure.rawValue)")
                #endif
                continue
            }
            #if DEBUG
            print("✅ Valid: \(movie.title)")
            #endif
            return movie
        }
        return nil
    }

    /// Returns all valid movies, sorted by score
    func selectValidMovies(from movies: [GWMovie], limit: Int = 10) -> [GWMovie] {
        let valid = movies.filter { validate($0) == nil }
        let scored = valid.map { ($0, computeScore(movie: $0, intent: intent)) }
        let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(limit).map { $0.0 })
    }
}

// MARK: - Section 6: Pure, Deterministic Recommendation Engine

func recommendMovie(
    user: GWValidationProfile,
    intent: GWIntent,
    history: [GWSpecInteraction],
    movies: [GWMovie],
    timeOfDay: TimeOfDay
) -> GWMovie? {
    // Build rejected IDs from history (everything except watch_now)
    let rejectedIds = Set(
        history
            .filter { $0.action != .watch_now }
            .map { $0.movie_id }
    )

    // Filter candidates through ALL validity rules
    let candidates = movies.filter { movie in
        // Rule 1: available
        guard movie.available == true else { return false }

        // Rule 2: language match
        let langMatch = user.preferred_languages.isEmpty || user.preferred_languages.contains { lang in
            movie.language.lowercased().contains(lang.lowercased()) ||
            (lang.lowercased() == "english" && movie.language.lowercased() == "en") ||
            (lang.lowercased() == "hindi" && movie.language.lowercased() == "hi")
        }
        guard langMatch else { return false }

        // Rule 3: platform intersection
        let platformMatch = user.platforms.isEmpty || !Set(movie.platforms.map { $0.lowercased() })
            .intersection(Set(user.platforms.map { $0.lowercased() }))
            .isEmpty
        guard platformMatch else { return false }

        // Rule 4: not rejected
        guard !rejectedIds.contains(movie.id) else { return false }

        // Rule 5: runtime in window
        guard movie.runtime >= user.runtime_window.min &&
              movie.runtime <= user.runtime_window.max else { return false }

        // Rule 6: goodscore threshold
        let threshold = goodscoreThreshold(mood: intent.mood, timeOfDay: timeOfDay)
        let normalizedScore = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
        guard normalizedScore >= threshold else { return false }

        // Rule 7: tag intersection
        let tagMatch = intent.intent_tags.isEmpty || !Set(movie.tags)
            .intersection(Set(intent.intent_tags))
            .isEmpty
        guard tagMatch else { return false }

        return true
    }

    if candidates.isEmpty { return nil }

    // Score and sort
    let scored = candidates.map { ($0, computeScore(movie: $0, intent: intent)) }
    let sorted = scored.sorted { $0.1 > $1.1 }

    return sorted.first?.0
}

// MARK: - Section 7: Rejection Learning (Stateful, Persistent)

/// Manages persistent tag weights for personalized scoring
/// Tag weights are now PER-USER to prevent data mixing on shared devices
class TagWeightStore {
    static let shared = TagWeightStore()

    private let legacyKey = "gw_tag_weights"
    private let keyPrefix = "gw_tag_weights_"
    private var currentUserId: String?

    // In-memory cache — avoids repeated UserDefaults + JSON decode on every call
    private var cachedWeights: [String: Double]?
    private var cachedForKey: String?

    private init() {}

    /// Set the current user for tag weight operations
    func setUser(_ userId: String) {
        // On first login, migrate legacy global weights to this user if they exist
        if currentUserId == nil {
            migrateGlobalWeightsIfNeeded(toUser: userId)
        }
        currentUserId = userId
        // Invalidate cache on user switch
        cachedWeights = nil
        cachedForKey = nil
    }

    private var userDefaultsKey: String {
        if let userId = currentUserId {
            return "\(keyPrefix)\(userId)"
        }
        return legacyKey // Fallback for pre-auth calls
    }

    /// Get current tag weights (default 1.0 for all tags)
    /// Uses in-memory cache to avoid repeated UserDefaults + JSON decode
    func getWeights() -> [String: Double] {
        let key = userDefaultsKey
        // Return cached if valid for current user key
        if let cached = cachedWeights, cachedForKey == key {
            return cached
        }
        // Load from UserDefaults (cold path — only on first access or user switch)
        guard let data = UserDefaults.standard.data(forKey: key),
              let weights = try? JSONDecoder().decode([String: Double].self, from: data) else {
            cachedWeights = [:]
            cachedForKey = key
            return [:]
        }
        cachedWeights = weights
        cachedForKey = key
        return weights
    }

    /// Get weight for a specific tag (default 1.0)
    func weight(for tag: String) -> Double {
        getWeights()[tag] ?? 1.0
    }

    /// Save updated weights (write-through: updates cache AND UserDefaults AND Supabase)
    func saveWeights(_ weights: [String: Double]) {
        let key = userDefaultsKey
        cachedWeights = weights
        cachedForKey = key
        if let data = try? JSONEncoder().encode(weights) {
            UserDefaults.standard.set(data, forKey: key)
        }
        pushWeightsToRemote(weights)
    }

    /// Reset all weights to default
    func resetWeights() {
        cachedWeights = nil
        cachedForKey = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Migrate legacy global weights to a user-specific key (one-time)
    private func migrateGlobalWeightsIfNeeded(toUser userId: String) {
        let userKey = "\(keyPrefix)\(userId)"
        // Only migrate if user has no weights yet AND global weights exist
        guard UserDefaults.standard.data(forKey: userKey) == nil,
              let globalData = UserDefaults.standard.data(forKey: legacyKey) else {
            return
        }
        UserDefaults.standard.set(globalData, forKey: userKey)
        // Remove legacy global key to prevent confusion
        UserDefaults.standard.removeObject(forKey: legacyKey)

        #if DEBUG
        print("[TagWeightStore] Migrated global tag weights to user \(userId)")
        #endif
    }

    // MARK: - Supabase Sync

    /// Sync tag weights from Supabase on app launch.
    /// - If local is empty but remote has data: use remote (reinstall recovery)
    /// - If local has data and remote has data: merge (remote wins, keep new local keys)
    /// - If local has data and remote is empty: push local to remote (first-time sync)
    func syncFromRemote() async {
        guard SupabaseConfig.isConfigured else { return }
        guard let userId = resolveUserId() else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/user_tag_weights_bulk?user_id=eq.\(userId)&select=weights"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                #if DEBUG
                print("[TagWeightSync] HTTP error fetching remote weights")
                #endif
                return
            }

            struct WeightRow: Decodable {
                let weights: [String: Double]
            }
            let rows = try JSONDecoder().decode([WeightRow].self, from: data)
            guard let remoteWeights = rows.first?.weights else {
                // No remote data — push local if we have any
                let localWeights = getWeights()
                if !localWeights.isEmpty {
                    pushWeightsToRemote(localWeights)
                    #if DEBUG
                    print("[TagWeightSync] First-time sync: pushed \(localWeights.count) tags to remote")
                    #endif
                }
                return
            }

            let localWeights = getWeights()

            #if DEBUG
            print("[TagWeightSync] Remote: \(remoteWeights.count) tags, Local: \(localWeights.count) tags")
            #endif

            if localWeights.isEmpty && !remoteWeights.isEmpty {
                // Reinstall recovery: use remote
                saveWeightsLocalOnly(remoteWeights)
                #if DEBUG
                print("[TagWeightSync] Restored \(remoteWeights.count) tags from remote (reinstall recovery)")
                #endif
            } else if !localWeights.isEmpty && !remoteWeights.isEmpty {
                // Merge: remote wins for shared keys, keep local-only keys
                var merged = remoteWeights
                for (tag, weight) in localWeights where merged[tag] == nil {
                    merged[tag] = weight
                }
                saveWeightsLocalOnly(merged)
                // Push merged back if there were local-only keys
                if merged.count > remoteWeights.count {
                    pushWeightsToRemote(merged)
                }
                #if DEBUG
                print("[TagWeightSync] Merged: \(merged.count) tags")
                #endif
            }
            // If both empty, nothing to do
        } catch {
            #if DEBUG
            print("[TagWeightSync] Fetch failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Save weights to cache + UserDefaults only (no remote push).
    /// Used by syncFromRemote to avoid re-triggering pushWeightsToRemote.
    private func saveWeightsLocalOnly(_ weights: [String: Double]) {
        let key = userDefaultsKey
        cachedWeights = weights
        cachedForKey = key
        if let data = try? JSONEncoder().encode(weights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Fire-and-forget upsert of full weight dictionary to Supabase.
    private func pushWeightsToRemote(_ weights: [String: Double]) {
        guard SupabaseConfig.isConfigured else { return }
        guard let userId = resolveUserId() else { return }

        Task.detached(priority: .utility) {
            let urlString = "\(SupabaseConfig.url)/rest/v1/user_tag_weights_bulk"
            guard let url = URL(string: urlString) else { return }

            let now = ISO8601DateFormatter().string(from: Date())
            let body: [String: Any] = [
                "user_id": userId,
                "weights": weights,
                "updated_at": now
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.timeoutInterval = 5.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                #if DEBUG
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    print("[TagWeightSync] Push failed: HTTP \(http.statusCode)")
                }
                #endif
            } catch {
                #if DEBUG
                print("[TagWeightSync] Push error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - User ID Resolution

    private func resolveUserId() -> String? {
        if let cachedId = UserService.shared.cachedUserId {
            return cachedId.uuidString
        }
        let keychainId = GWKeychainManager.shared.getOrCreateAnonymousUserId()
        return keychainId.isEmpty ? nil : keychainId
    }
}

/// Updates tag weights based on user action
/// - watch_now: +0.15 (user chose to watch — meaningful positive reinforcement)
/// - completed: +0.2 (user finished watching — strong positive signal)
/// - not_tonight: -0.2 (user rejected movies with these tags — significant negative)
/// - abandoned: -0.4 (user strongly disliked movies with these tags)
/// - show_me_another: -0.05 (user wasn't excited — mild negative that accumulates)
///
/// Deltas are calibrated so learning produces visible ranking changes:
/// - After 2 rejections of "dark" movies: weight goes 1.0 → 0.6 (meaningful shift)
/// - After 1 watch of "feel_good": weight goes 1.0 → 1.15 (noticeable boost)
/// - After 5 skips of same tag: weight drops by 0.25 (equivalent to 1 rejection)
func updateTagWeights(
    tagWeights: [String: Double],
    movie: GWMovie,
    action: GWSpecInteraction.SpecInteractionAction
) -> [String: Double] {
    let delta: Double
    switch action {
    case .completed:
        delta = 0.2
    case .not_tonight:
        delta = -0.2
    case .abandoned:
        delta = -0.4
    case .watch_now:
        delta = 0.15 // Meaningful positive reinforcement for acceptance
    case .show_me_another:
        delta = -0.05 // Mild negative: accumulates to meaningful signal after several skips
    case .implicit_skip:
        delta = -0.05 // Multi-pick: same as show_me_another
    }

    var updated = tagWeights
    for tag in movie.tags {
        let currentWeight = updated[tag] ?? 1.0
        updated[tag] = currentWeight + delta
    }

    return updated
}

/// Applies tag weights to compute a weighted score
func computeWeightedScore(movie: GWMovie, intent: GWIntent, tagWeights: [String: Double]) -> Double {
    let movieTags = Set(movie.tags)
    let intentTags = Set(intent.intent_tags)

    // Tag alignment with weights applied
    let intersection = movieTags.intersection(intentTags)
    var weightedAlignment = 0.0
    var totalWeight = 0.0

    for tag in intentTags {
        let weight = tagWeights[tag] ?? 1.0
        totalWeight += weight
        if intersection.contains(tag) {
            weightedAlignment += weight
        }
    }

    let tagAlignment = totalWeight > 0 ? weightedAlignment / totalWeight : 0.0

    // Regret safety (also weighted)
    let regretSafety: Double
    if movieTags.contains(RegretRisk.safe_bet.rawValue) {
        regretSafety = 1.0 * (tagWeights[RegretRisk.safe_bet.rawValue] ?? 1.0)
    } else if movieTags.contains(RegretRisk.polarizing.rawValue) {
        regretSafety = 0.4 * (tagWeights[RegretRisk.polarizing.rawValue] ?? 1.0)
    } else {
        regretSafety = 0.6 * (tagWeights[RegretRisk.acquired_taste.rawValue] ?? 1.0)
    }

    // Normalize regret safety to 0-1 range
    let normalizedRegretSafety = min(max(regretSafety, 0), 1)

    // Final score
    return (tagAlignment * 0.6) + (normalizedRegretSafety * 0.4)
}

/// Record interaction and update tag weights persistently
func recordInteractionAndUpdateWeights(movie: GWMovie, action: GWSpecInteraction.SpecInteractionAction) {
    let store = TagWeightStore.shared
    let currentWeights = store.getWeights()
    let updatedWeights = updateTagWeights(tagWeights: currentWeights, movie: movie, action: action)
    store.saveWeights(updatedWeights)

    #if DEBUG
    print("📊 Tag weights updated for \(movie.title) [\(action.rawValue)]:")
    for tag in movie.tags {
        let oldWeight = currentWeights[tag] ?? 1.0
        let newWeight = updatedWeights[tag] ?? 1.0
        if oldWeight != newWeight {
            print("   \(tag): \(String(format: "%.2f", oldWeight)) → \(String(format: "%.2f", newWeight))")
        }
    }
    #endif
}

// MARK: - Section 9: Runtime Assertions (Live Bug Catching)

/// Validation errors thrown by assertValid
enum GWValidationError: Error, CustomStringConvertible {
    case languageViolation(movieLang: String, userLangs: [String])
    case platformViolation(moviePlatforms: [String], userPlatforms: [String])
    case runtimeViolation(movieRuntime: Int, userWindow: (min: Int, max: Int))
    case goodscoreViolation(movieScore: Double, threshold: Double)
    case tagViolation(movieTags: [String], intentTags: [String])
    case rejectedMovieViolation(movieId: String)

    var description: String {
        switch self {
        case .languageViolation(let movieLang, let userLangs):
            return "LANGUAGE_VIOLATION: movie '\(movieLang)' not in user languages \(userLangs)"
        case .platformViolation(let moviePlatforms, let userPlatforms):
            return "PLATFORM_VIOLATION: movie platforms \(moviePlatforms) have no intersection with user platforms \(userPlatforms)"
        case .runtimeViolation(let runtime, let window):
            return "RUNTIME_VIOLATION: movie runtime \(runtime) outside user window (\(window.min)-\(window.max))"
        case .goodscoreViolation(let score, let threshold):
            return "GOODSCORE_VIOLATION: movie score \(score) below threshold \(threshold)"
        case .tagViolation(let movieTags, let intentTags):
            return "TAG_VIOLATION: movie tags \(movieTags) have no intersection with intent tags \(intentTags)"
        case .rejectedMovieViolation(let movieId):
            return "REJECTED_MOVIE_VIOLATION: movie \(movieId) was previously rejected"
        }
    }
}

/// Runtime assertion that validates a movie recommendation against user profile and intent
/// Throws GWValidationError if any rule is violated - this catches bugs in recommendation logic
func assertValid(
    movie: GWMovie,
    user: GWValidationProfile,
    intent: GWIntent,
    rejectedIds: Set<String> = []
) throws {
    // Rule 1: Language match
    if !user.preferred_languages.isEmpty {
        let movieLang = movie.language.lowercased()
        let langMatch = user.preferred_languages.contains { lang in
            let loweredLang = lang.lowercased()
            return movieLang.contains(loweredLang) ||
                   (loweredLang == "english" && movieLang == "en") ||
                   (loweredLang == "hindi" && movieLang == "hi")
        }
        if !langMatch {
            throw GWValidationError.languageViolation(
                movieLang: movie.language,
                userLangs: user.preferred_languages
            )
        }
    }

    // Rule 2: Platform intersection
    if !user.platforms.isEmpty {
        let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
        let userPlatforms = Set(user.platforms.map { $0.lowercased() })
        if moviePlatforms.intersection(userPlatforms).isEmpty {
            throw GWValidationError.platformViolation(
                moviePlatforms: movie.platforms,
                userPlatforms: user.platforms
            )
        }
    }

    // Rule 3: Not in rejected set
    if rejectedIds.contains(movie.id) {
        throw GWValidationError.rejectedMovieViolation(movieId: movie.id)
    }

    // Rule 4: Runtime in window
    if movie.runtime < user.runtime_window.min || movie.runtime > user.runtime_window.max {
        throw GWValidationError.runtimeViolation(
            movieRuntime: movie.runtime,
            userWindow: user.runtime_window
        )
    }

    // Rule 5: GoodScore threshold
    let threshold = goodscoreThreshold(mood: intent.mood, timeOfDay: TimeOfDay.current)
    let normalizedScore = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
    if normalizedScore < threshold {
        throw GWValidationError.goodscoreViolation(
            movieScore: normalizedScore,
            threshold: threshold
        )
    }

    // Rule 6: Tag intersection
    if !intent.intent_tags.isEmpty {
        let movieTags = Set(movie.tags)
        let intentTags = Set(intent.intent_tags)
        if movieTags.intersection(intentTags).isEmpty {
            throw GWValidationError.tagViolation(
                movieTags: movie.tags,
                intentTags: intent.intent_tags
            )
        }
    }

    #if DEBUG
    print("✅ assertValid passed for: \(movie.title)")
    #endif
}

/// Convenience method to validate without throwing - returns validation result
func isValid(
    movie: GWMovie,
    user: GWValidationProfile,
    intent: GWIntent,
    rejectedIds: Set<String> = []
) -> (valid: Bool, error: GWValidationError?) {
    do {
        try assertValid(movie: movie, user: user, intent: intent, rejectedIds: rejectedIds)
        return (true, nil)
    } catch let error as GWValidationError {
        return (false, error)
    } catch {
        return (false, nil)
    }
}

/// Debug helper to log validation failures
func debugValidation(
    movie: GWMovie,
    user: GWValidationProfile,
    intent: GWIntent,
    rejectedIds: Set<String> = []
) {
    #if DEBUG
    let result = isValid(movie: movie, user: user, intent: intent, rejectedIds: rejectedIds)
    if !result.valid {
        print("🚨 VALIDATION FAILED for \(movie.title):")
        if let error = result.error {
            print("   \(error.description)")
        }
    }
    #endif
}

// MARK: - Section 11: UI Contract (STRICT)
//
// Rules:
// - UI receives EXACTLY ONE Movie or null
// - UI NEVER filters
// - UI NEVER overrides logic
// - UI NEVER explains GoodScore math
// - UI trusts engine completely

/// The result type that the UI receives from the recommendation engine
/// Enforces the contract: exactly ONE movie or null
struct GWRecommendationResult {
    /// The single recommended movie, or nil if no valid candidate
    let movie: GWMovie?

    /// Whether a valid recommendation was found
    var hasRecommendation: Bool { movie != nil }

    /// Stop condition that caused nil result (if applicable)
    let stopCondition: GWStopCondition?

    /// Creates a successful recommendation result
    static func success(_ movie: GWMovie) -> GWRecommendationResult {
        GWRecommendationResult(movie: movie, stopCondition: nil)
    }

    /// Creates a failed result with stop condition
    static func stopped(_ condition: GWStopCondition) -> GWRecommendationResult {
        GWRecommendationResult(movie: nil, stopCondition: condition)
    }
}

/// UI-safe wrapper that provides exactly what the UI needs
/// UI should NEVER access raw movie arrays or filter logic
struct GWUIPayload {
    let title: String
    let year: String
    let runtime: String
    let posterURL: String?
    let overview: String?
    let platforms: [String]
    let genres: [String]

    /// DO NOT expose goodscore calculation details to UI
    /// UI should only show the final score, never the math
    let goodscoreDisplay: Int

    /// Tags for display (NOT for filtering - UI must not filter)
    let displayTags: [String]

    /// Create from GWMovie - this is the ONLY way UI gets movie data
    init(from movie: GWMovie) {
        self.title = movie.title
        self.year = String(movie.year)
        self.runtime = "\(movie.runtime) min"
        self.posterURL = movie.poster_url
        self.overview = movie.overview
        self.platforms = movie.platforms
        self.genres = movie.genres
        self.goodscoreDisplay = Int(movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10)
        self.displayTags = movie.tags
    }
}

// MARK: - Section 12: Stop Conditions

/// Reasons why recommendation engine returns null
enum GWStopCondition: String, CustomStringConvertible {
    /// No candidate passes all validity rules
    case noCandidatePassesValidity = "no_candidate_passes_validity"

    /// User has rejected all available options
    case allOptionsExhausted = "all_options_exhausted"

    /// No movies available on user's platforms
    case noPlatformMatch = "no_platform_match"

    /// No movies in user's preferred languages
    case noLanguageMatch = "no_language_match"

    /// No movies match the OTT + Language combination (e.g., Hindi on Apple TV+)
    case ottLanguageCombinationMismatch = "ott_language_combination_mismatch"

    /// All movies below goodscore threshold
    case allBelowThreshold = "all_below_threshold"

    /// No movies match user's intent tags
    case noTagMatch = "no_tag_match"

    /// Empty movie catalog
    case emptyCatalog = "empty_catalog"

    /// No series available when user selected Series/Binge
    case noSeriesAvailable = "no_series_available"

    /// No movies available when user didn't select Series/Binge
    case noMoviesAvailable = "no_movies_available"

    var description: String {
        switch self {
        case .noCandidatePassesValidity:
            return "You've seen all the movies matching your filters. Your combination of platform, language, and duration has limited options. Try adjusting your filters or check back later for new additions."
        case .allOptionsExhausted:
            return "You've seen all our top picks for tonight! Check back tomorrow for fresh recommendations."
        case .noPlatformMatch:
            return "We don't have movies available on your selected streaming platforms right now. Try adding more platforms."
        case .noLanguageMatch:
            return "No movies found in your preferred language. Try selecting additional languages."
        case .ottLanguageCombinationMismatch:
            return "Your selected streaming platforms have very limited content in your preferred language. Try selecting different platforms or adding more languages."
        case .allBelowThreshold:
            return "No movies meet our quality bar for your current mood. Try selecting a different mood?"
        case .noTagMatch:
            return "No movies match your current mood preferences. Try selecting a different mood?"
        case .emptyCatalog:
            return "We're updating our catalog. Please try again in a few moments."
        case .noSeriesAvailable:
            return "We don't have series matching your other preferences right now. Try selecting a movie duration instead."
        case .noMoviesAvailable:
            return "No movies match your current filters. Try adjusting your preferences."
        }
    }

    /// User-friendly short message
    var shortMessage: String {
        switch self {
        case .noCandidatePassesValidity:
            return "No perfect match found"
        case .allOptionsExhausted:
            return "All caught up!"
        case .noPlatformMatch:
            return "No platform match"
        case .noLanguageMatch:
            return "No language match"
        case .ottLanguageCombinationMismatch:
            return "Limited content available"
        case .allBelowThreshold:
            return "Quality threshold not met"
        case .noTagMatch:
            return "Mood mismatch"
        case .emptyCatalog:
            return "Catalog updating"
        case .noSeriesAvailable:
            return "No series available"
        case .noMoviesAvailable:
            return "No movies available"
        }
    }
}

/// Analyzes why no valid movie was found and returns the appropriate stop condition
func diagnoseStopCondition(
    movies: [GWMovie],
    user: GWValidationProfile,
    intent: GWIntent,
    rejectedIds: Set<String>
) -> GWStopCondition {
    // Check empty catalog first
    if movies.isEmpty {
        return .emptyCatalog
    }

    // Check if all movies are rejected
    let nonRejected = movies.filter { !rejectedIds.contains($0.id) }
    if nonRejected.isEmpty {
        return .allOptionsExhausted
    }

    // Check platform match
    var platformMatches: [GWMovie] = []
    if !user.platforms.isEmpty {
        platformMatches = nonRejected.filter { movie in
            let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
            let userPlatforms = Set(user.platforms.map { $0.lowercased() })
            return !moviePlatforms.intersection(userPlatforms).isEmpty
        }
        if platformMatches.isEmpty {
            return .noPlatformMatch
        }
    } else {
        platformMatches = nonRejected
    }

    // Check language match
    var languageMatches: [GWMovie] = []
    if !user.preferred_languages.isEmpty {
        languageMatches = nonRejected.filter { movie in
            let movieLang = movie.language.lowercased()
            return user.preferred_languages.contains { lang in
                let loweredLang = lang.lowercased()
                return movieLang.contains(loweredLang) ||
                       (loweredLang == "english" && movieLang == "en") ||
                       (loweredLang == "hindi" && movieLang == "hi")
            }
        }
        if languageMatches.isEmpty {
            return .noLanguageMatch
        }
    } else {
        languageMatches = nonRejected
    }

    // Check OTT + Language combination match
    // This detects when platform matches exist AND language matches exist
    // but NO movies match BOTH criteria simultaneously
    if !user.platforms.isEmpty && !user.preferred_languages.isEmpty {
        let combinedMatches = nonRejected.filter { movie in
            // Check platform match
            let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
            let userPlatforms = Set(user.platforms.map { $0.lowercased() })
            let hasPlatformMatch = !moviePlatforms.intersection(userPlatforms).isEmpty

            // Check language match
            let movieLang = movie.language.lowercased()
            let hasLanguageMatch = user.preferred_languages.contains { lang in
                let loweredLang = lang.lowercased()
                return movieLang.contains(loweredLang) ||
                       (loweredLang == "english" && movieLang == "en") ||
                       (loweredLang == "hindi" && movieLang == "hi")
            }

            return hasPlatformMatch && hasLanguageMatch
        }

        // If individual matches exist but combined doesn't, it's an OTT+Language mismatch
        if combinedMatches.isEmpty && !platformMatches.isEmpty && !languageMatches.isEmpty {
            return .ottLanguageCombinationMismatch
        }
    }

    // Check tag match
    if !intent.intent_tags.isEmpty {
        let tagMatches = nonRejected.filter { movie in
            let movieTags = Set(movie.tags)
            let intentTags = Set(intent.intent_tags)
            return !movieTags.intersection(intentTags).isEmpty
        }
        if tagMatches.isEmpty {
            return .noTagMatch
        }
    }

    // Check goodscore threshold
    let threshold = goodscoreThreshold(mood: intent.mood, timeOfDay: TimeOfDay.current)
    let aboveThreshold = nonRejected.filter { movie in
        let normalizedScore = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
        return normalizedScore >= threshold
    }
    if aboveThreshold.isEmpty {
        return .allBelowThreshold
    }

    // Default: general validity failure
    return .noCandidatePassesValidity
}

/// Main entry point for UI - returns exactly one movie or null with stop condition
/// This is the ONLY function the UI should call for recommendations
func getRecommendationForUI(
    user: GWValidationProfile,
    intent: GWIntent,
    history: [GWSpecInteraction],
    movies: [GWMovie]
) -> GWRecommendationResult {
    // Build rejected IDs from history
    let rejectedIds = Set(
        history
            .filter { $0.action != .watch_now }
            .map { $0.movie_id }
    )

    // Get recommendation
    let movie = recommendMovie(
        user: user,
        intent: intent,
        history: history,
        movies: movies,
        timeOfDay: TimeOfDay.current
    )

    if let movie = movie {
        return .success(movie)
    } else {
        let stopCondition = diagnoseStopCondition(
            movies: movies,
            user: user,
            intent: intent,
            rejectedIds: rejectedIds
        )
        return .stopped(stopCondition)
    }
}
