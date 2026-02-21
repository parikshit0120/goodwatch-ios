import Foundation

// ============================================
// GOODWATCH RECOMMENDATION ENGINE
// ============================================
// FROZEN: Canonical recommendation logic.
// ALL filtering, scoring, and validation lives here.
// GWProductionSafety.swift adds PROD-safe wrappers around this.
// ============================================

// MARK: - Supporting Types

struct GWRuntimeWindow: Codable {
    let min: Int
    let max: Int
}

enum GWRecommendationStyle: String, Codable {
    case safe       // Higher thresholds, safer picks
    case balanced   // Default behavior
    case adventurous // Lower thresholds, more variety
}

struct GWRecommendationOutput: Equatable {
    let movie: GWMovie?
    let stopCondition: GWStopCondition?

    static func == (lhs: GWRecommendationOutput, rhs: GWRecommendationOutput) -> Bool {
        lhs.movie?.id == rhs.movie?.id && lhs.stopCondition == rhs.stopCondition
    }
}

enum GWMovieValidationResult {
    case valid
    case invalid(GWValidationFailure)
}

enum GWValidationFailure: CustomStringConvertible {
    case languageMismatch(movieLang: String, userLangs: [String])
    case platformMismatch(moviePlatforms: [String], userPlatforms: [String])
    case alreadyInteracted(id: String, reason: String)
    case runtimeOutOfWindow(runtime: Int, window: (min: Int, max: Int))
    case goodscoreBelowThreshold(score: Double, threshold: Double)
    case noMatchingTags(movieTags: [String], intentTags: [String])
    case movieUnavailable
    case contentTypeMismatch(expected: String, actual: String?)
    case qualityGateFailed(rating: Double, voteCount: Int)
    case recencyGateFailed(year: Int)

    var ruleLabel: String {
        switch self {
        case .languageMismatch: return "language"
        case .platformMismatch: return "platform"
        case .alreadyInteracted: return "interacted"
        case .runtimeOutOfWindow: return "runtime"
        case .goodscoreBelowThreshold: return "goodscore"
        case .noMatchingTags: return "tags"
        case .movieUnavailable: return "unavailable"
        case .contentTypeMismatch: return "contentType"
        case .qualityGateFailed: return "qualityGate"
        case .recencyGateFailed: return "recencyGate"
        }
    }

    var description: String {
        switch self {
        case .languageMismatch(let movieLang, let userLangs):
            return "LANGUAGE_MISMATCH: movie '\(movieLang)' not in user languages \(userLangs)"
        case .platformMismatch(let moviePlatforms, let userPlatforms):
            return "PLATFORM_MISMATCH: movie platforms \(moviePlatforms) vs user platforms \(userPlatforms)"
        case .alreadyInteracted(let id, let reason):
            return "ALREADY_INTERACTED: movie \(id) - \(reason)"
        case .runtimeOutOfWindow(let runtime, let window):
            return "RUNTIME_OUT_OF_WINDOW: \(runtime)min outside \(window.min)-\(window.max)"
        case .goodscoreBelowThreshold(let score, let threshold):
            return "GOODSCORE_BELOW_THRESHOLD: \(score) < \(threshold)"
        case .noMatchingTags(let movieTags, let intentTags):
            return "NO_MATCHING_TAGS: movie \(movieTags) vs intent \(intentTags)"
        case .movieUnavailable:
            return "MOVIE_UNAVAILABLE: no streaming platforms"
        case .contentTypeMismatch(let expected, let actual):
            return "CONTENT_TYPE_MISMATCH: expected \(expected), got \(actual ?? "nil")"
        case .qualityGateFailed(let rating, let voteCount):
            return "QUALITY_GATE_FAILED: rating \(rating), votes \(voteCount)"
        case .recencyGateFailed(let year):
            return "RECENCY_GATE_FAILED: movie year \(year) < 2010"
        }
    }
}

// MARK: - Time of Day (Engine-specific)

enum GWTimeOfDay: String, Codable {
    case morning
    case afternoon
    case evening
    case lateNight = "late_night"

    static var current: GWTimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .lateNight
        }
    }
}

// MARK: - GoodScore Threshold (Canonical)

func gwGoodscoreThreshold(mood: String, timeOfDay: GWTimeOfDay, style: GWRecommendationStyle) -> Double {
    var base: Double

    // Base threshold from mood
    switch mood.lowercased() {
    case "tired":
        base = 88
    case "adventurous":
        base = 75
    default:
        base = 80
    }

    // Time of day adjustment
    if timeOfDay == .lateNight {
        base = max(base, 85) // Late night = only safe bets
    }

    // Style adjustment
    switch style {
    case .safe:
        break // Keep base
    case .balanced:
        base -= 2
    case .adventurous:
        base = 70 // Override: adventurous users get more variety
    }

    return base
}

// MARK: - User Profile (Canonical)

struct GWUserProfileComplete {
    var userId: String
    var preferredLanguages: [String]
    var platforms: [String]
    var runtimeWindow: GWRuntimeWindow
    var mood: String
    var intentTags: [String]
    var seen: [String]
    var notTonight: Set<String>
    var abandoned: [String]
    var recommendationStyle: GWRecommendationStyle
    var tagWeights: [String: Double]
    var requiresSeries: Bool
    var platformBias: GWPlatformBias
    var dimensionalLearning: GWDimensionalLearning
    var tasteProfile: GWUserTasteProfile?
    var moodMapping: GWMoodMapping?
    var applyRecencyGate: Bool  // true when interaction_points < 10 and feature flag enabled

    /// All excluded movie IDs (seen + notTonight + abandoned)
    var allExcludedIds: Set<String> {
        var excluded = Set<String>()
        excluded.formUnion(seen)
        excluded.formUnion(notTonight)
        excluded.formUnion(abandoned)
        return excluded
    }

    init(
        userId: String,
        preferredLanguages: [String],
        platforms: [String],
        runtimeWindow: GWRuntimeWindow,
        mood: String,
        intentTags: [String],
        seen: [String],
        notTonight: Any, // Accept both Set<String> and [String]
        abandoned: [String],
        recommendationStyle: GWRecommendationStyle,
        tagWeights: [String: Double],
        requiresSeries: Bool = false,
        platformBias: GWPlatformBias = GWPlatformBias(),
        dimensionalLearning: GWDimensionalLearning = GWDimensionalLearning(),
        tasteProfile: GWUserTasteProfile? = nil,
        moodMapping: GWMoodMapping? = nil,
        applyRecencyGate: Bool = false
    ) {
        self.userId = userId
        self.preferredLanguages = preferredLanguages
        self.platforms = platforms
        self.runtimeWindow = runtimeWindow
        self.mood = mood
        self.intentTags = intentTags
        self.seen = seen
        if let set = notTonight as? Set<String> {
            self.notTonight = set
        } else if let arr = notTonight as? [String] {
            self.notTonight = Set(arr)
        } else {
            self.notTonight = []
        }
        self.abandoned = abandoned
        self.recommendationStyle = recommendationStyle
        self.tagWeights = tagWeights
        self.requiresSeries = requiresSeries
        self.platformBias = platformBias
        self.dimensionalLearning = dimensionalLearning
        self.tasteProfile = tasteProfile
        self.moodMapping = moodMapping
        self.applyRecencyGate = applyRecencyGate
    }

    /// Build from UserContext (used in EmotionalHookView and MovieFilter)
    static func from(context: UserContext, userId: String, excludedIds: [String]) -> GWUserProfileComplete {
        // Load learning data from local storage
        let learningData = InteractionService.shared.getLearningData(
            userId: UUID(uuidString: userId) ?? UUID()
        )

        // Load taste profile from cache (computed after each feedback submission)
        let tasteProfile = GWTasteEngine.shared.getCachedProfile(userId: userId)

        // Load remote mood mapping (INV-R11)
        let moodKey = context.intent.mood
        let moodMapping = GWMoodConfigService.shared.getMoodMapping(for: moodKey)

        // Populate intentTags from remote mapping if available, else use hardcoded
        let resolvedIntentTags: [String]
        if let mapping = moodMapping, mapping.version > 0 {
            resolvedIntentTags = mapping.compatibleTags
        } else {
            resolvedIntentTags = context.intent.intent_tags
        }

        // Recency gate: exclude pre-2010 movies for new users (interaction_points < 10)
        let recencyGateEnabled = GWFeatureFlags.shared.isEnabled("new_user_recency_gate")
        GWInteractionPoints.shared.setUser(userId)
        let shouldApplyRecencyGate = recencyGateEnabled && GWInteractionPoints.shared.currentPoints < 10

        return GWUserProfileComplete(
            userId: userId,
            preferredLanguages: context.languages.map { $0.rawValue },
            platforms: context.otts.map { $0.rawValue },
            runtimeWindow: GWRuntimeWindow(min: context.minDuration, max: context.maxDuration),
            mood: context.mood.rawValue,
            intentTags: resolvedIntentTags,
            seen: [],
            notTonight: Set(excludedIds),
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: TagWeightStore.shared.getWeights(),
            requiresSeries: context.requiresSeries,
            platformBias: learningData.platformBias,
            dimensionalLearning: learningData.dimensional,
            tasteProfile: tasteProfile,
            moodMapping: moodMapping,
            applyRecencyGate: shouldApplyRecencyGate
        )
    }
}

// MARK: - New User Content Filter

struct GWNewUserContentFilter {
    let maturityInfo: InteractionService.UserMaturityInfo

    var shouldShowDocumentaries: Bool {
        maturityInfo.shouldShowDocumentaries
    }

    /// Whether user has shown interest in kids/animated content
    var shouldShowKidsContent: Bool {
        maturityInfo.hasWatchedKidsContent
    }

    /// Check if a movie should be excluded based on new-user content rules
    func shouldExclude(movie: GWMovie) -> Bool {
        let genres = movie.genres.map { $0.lowercased() }

        // Filter documentaries for new users unless they've explicitly picked one
        if !shouldShowDocumentaries {
            if genres.contains("documentary") {
                return true
            }
        }

        // Filter kids/animation/family content unless user has explicitly engaged with it.
        // Prevents "Frog and Toad" for adult users wanting "feel-good" content.
        if !shouldShowKidsContent {
            let kidsGenres: Set<String> = ["animation", "kids", "family"]
            let movieGenres = Set(genres)
            if !movieGenres.intersection(kidsGenres).isEmpty {
                // Allow animated movies that are clearly adult-oriented
                // (high rating + enough votes + has non-kids genres like drama/thriller/sci-fi)
                let adultGenres: Set<String> = ["drama", "thriller", "crime", "sci-fi", "science fiction",
                                                 "horror", "mystery", "war", "romance", "history"]
                let hasAdultGenre = !movieGenres.intersection(adultGenres).isEmpty
                let isHighQuality = movie.goodscore >= 7.5 && movie.voteCount >= 5000
                if !(hasAdultGenre && isHighQuality) {
                    return true
                }
            }
        }

        // Filter musicals for new users (polarizing for general audience)
        if !shouldShowDocumentaries {
            if genres.contains("music") || genres.contains("musical") {
                return true
            }
        }

        return false
    }
}

// MARK: - Catalog Availability Check

struct GWCatalogAvailability {
    let totalMovies: Int
    let platformMatches: Int
    let languageMatches: Int
    let runtimeMatches: Int
    let contentTypeMatches: Int
    let qualityMatches: Int
    let combinedMatches: Int
    let issue: GWAvailabilityIssue?

    var hasAvailableMovies: Bool {
        combinedMatches > 0
    }
}

struct GWAvailabilityIssue {
    let title: String
    let message: String
    let suggestedAction: SuggestedAction

    enum SuggestedAction {
        case changePlatforms
        case changeLanguage
        case changeRuntime
    }
}

// MARK: - Recommendation Engine

final class GWRecommendationEngine {
    static let shared = GWRecommendationEngine()
    private init() {}

    // ============================================
    // SECTION 1: Movie Validation
    // ============================================

    /// Validate a single movie against user profile
    func isValidMovie(_ movie: GWMovie, profile: GWUserProfileComplete) -> GWMovieValidationResult {
        // Rule 0: Movie must be available
        if !movie.available {
            return .invalid(.movieUnavailable)
        }

        // Rule 1: Language match
        if !profile.preferredLanguages.isEmpty {
            let movieLang = movie.language.lowercased()
            let langMatch = profile.preferredLanguages.contains { lang in
                let l = lang.lowercased()
                return movieLang.contains(l) ||
                       (l == "english" && movieLang == "en") ||
                       (l == "hindi" && movieLang == "hi") ||
                       (l == "tamil" && movieLang == "ta") ||
                       (l == "telugu" && movieLang == "te") ||
                       (l == "malayalam" && movieLang == "ml") ||
                       (l == "kannada" && movieLang == "kn") ||
                       (l == "marathi" && movieLang == "mr") ||
                       (l == "korean" && movieLang == "ko") ||
                       (l == "japanese" && movieLang == "ja") ||
                       (l == "spanish" && movieLang == "es") ||
                       (l == "french" && movieLang == "fr")
            }
            if !langMatch {
                return .invalid(.languageMismatch(
                    movieLang: movie.language,
                    userLangs: profile.preferredLanguages
                ))
            }
        }

        // Rule 2: Platform match
        if !profile.platforms.isEmpty {
            let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
            let userPlatforms = Set(profile.platforms.map { $0.lowercased() })

            // Expand platform names for matching
            var expandedUserPlatforms = Set<String>()
            for platform in userPlatforms {
                expandedUserPlatforms.insert(platform)
                switch platform {
                case "netflix":
                    expandedUserPlatforms.insert("netflix kids")
                case "prime", "amazon_prime":
                    expandedUserPlatforms.formUnion(["amazon prime video", "amazon prime video with ads", "amazon video", "prime video"])
                case "jio_hotstar":
                    expandedUserPlatforms.formUnion(["jiohotstar", "hotstar", "disney+ hotstar", "jio hotstar"])
                case "apple_tv":
                    expandedUserPlatforms.formUnion(["apple tv", "apple tv+"])
                case "sony_liv":
                    expandedUserPlatforms.formUnion(["sony liv", "sonyliv"])
                case "zee5":
                    break
                default:
                    break
                }
            }

            let hasMatch = moviePlatforms.contains { moviePlat in
                expandedUserPlatforms.contains { userPlat in
                    moviePlat.contains(userPlat) || userPlat.contains(moviePlat)
                }
            }

            if !hasMatch {
                return .invalid(.platformMismatch(
                    moviePlatforms: movie.platforms,
                    userPlatforms: profile.platforms
                ))
            }
        }

        // Rule 3: Not already interacted
        if profile.allExcludedIds.contains(movie.id) {
            let reason: String
            if profile.seen.contains(movie.id) {
                reason = "seen"
            } else if profile.notTonight.contains(movie.id) {
                reason = "not_tonight"
            } else {
                reason = "abandoned"
            }
            return .invalid(.alreadyInteracted(id: movie.id, reason: reason))
        }

        // Rule 4: Runtime in window
        if movie.runtime < profile.runtimeWindow.min || movie.runtime > profile.runtimeWindow.max {
            return .invalid(.runtimeOutOfWindow(
                runtime: movie.runtime,
                window: (min: profile.runtimeWindow.min, max: profile.runtimeWindow.max)
            ))
        }

        // Rule 4B: Exclude shorts (< 40 min runtime for non-series content)
        if !movie.isSeries && movie.runtime > 0 && movie.runtime < 40 {
            return .invalid(.runtimeOutOfWindow(
                runtime: movie.runtime,
                window: (min: 40, max: profile.runtimeWindow.max)
            ))
        }

        // Rule 4C: Exclude stand-up specials, concert films, behind-the-scenes
        let genreLower = movie.genres.map { $0.lowercased() }
        let titleLower = movie.title.lowercased()
        let isStandUp = genreLower.contains(where: { $0.contains("stand-up") || $0.contains("stand up") || $0.contains("comedy special") })
            || titleLower.contains("stand-up") || titleLower.contains("stand up") || titleLower.contains("comedy special")
        let isConcert = genreLower.contains("concert") || titleLower.contains("concert film")
        let isBehindScenes = titleLower.contains("behind the scenes") || titleLower.contains("making of")
        if isStandUp || isConcert || isBehindScenes {
            return .invalid(.contentTypeMismatch(expected: "movie", actual: "excluded_content"))
        }

        // Rule 5: Content type match
        // If user requires series → exclude movies
        // If user does NOT require series → exclude series (prevent TV shows for movie users)
        if profile.requiresSeries {
            if !movie.isSeries {
                return .invalid(.contentTypeMismatch(expected: "series", actual: movie.contentType))
            }
        } else {
            // User wants movies — filter OUT anything that looks like a series
            if movie.isSeries {
                return .invalid(.contentTypeMismatch(expected: "movie", actual: movie.contentType))
            }
        }

        // Rule 5B: Recency gate for new users
        // Exclude pre-2010 movies when interaction_points < 10 (feature-flagged)
        if profile.applyRecencyGate && movie.year < 2010 {
            return .invalid(.recencyGateFailed(year: movie.year))
        }

        // Rule 6: GoodScore threshold
        // If composite_score is available (> 0), prefer it for the threshold check
        var threshold = gwGoodscoreThreshold(
            mood: profile.mood,
            timeOfDay: GWTimeOfDay.current,
            style: profile.recommendationStyle
        )

        // Language-aware threshold adjustment:
        // Languages with fewer than ~20 movies at 8.0+ (composite_score >= 8.0)
        // get a 10-point threshold reduction so users see ~50+ quality titles.
        // If user has BOTH English and a small-catalog language, the adjustment
        // applies only to the small-catalog language content.
        let smallCatalogLanguages: Set<String> = [
            "hi", "hindi", "ta", "tamil", "te", "telugu",
            "ml", "malayalam", "kn", "kannada", "mr", "marathi",
            "ko", "korean", "ja", "japanese"
        ]
        let movieLangLower = movie.language.lowercased()
        let isSmallCatalogLanguage = smallCatalogLanguages.contains(movieLangLower)

        if isSmallCatalogLanguage {
            // Lower threshold by 10 for small-catalog languages (80 -> 70, 88 -> 78)
            // Floor at 65 to maintain minimum quality
            threshold = max(65, threshold - 10)
        }

        let scoreForCheck: Double
        if movie.composite_score > 0 {
            // composite_score is already on 0-100 scale
            scoreForCheck = movie.composite_score
        } else {
            scoreForCheck = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
        }
        if scoreForCheck < threshold {
            return .invalid(.goodscoreBelowThreshold(
                score: scoreForCheck,
                threshold: threshold
            ))
        }

        // Rule 7: Mood filter (dimensional + tag)
        // If remote mood mapping with dimensional ranges is available and movie has emotional profile,
        // use dimensional range checks + anti-tag filtering.
        // Otherwise, fall back to tag intersection (original behavior).
        if let mapping = profile.moodMapping, mapping.version > 0 {
            if !passesRemoteMoodFilter(movie: movie, mapping: mapping, intentTags: profile.intentTags) {
                return .invalid(.noMatchingTags(
                    movieTags: movie.tags,
                    intentTags: profile.intentTags
                ))
            }
        } else {
            // Fallback: original tag intersection
            if !profile.intentTags.isEmpty {
                let movieTags = Set(movie.tags)
                let intentTags = Set(profile.intentTags)
                if movieTags.intersection(intentTags).isEmpty {
                    return .invalid(.noMatchingTags(
                        movieTags: movie.tags,
                        intentTags: profile.intentTags
                    ))
                }
            }
        }

        return .valid
    }

    // ============================================
    // SECTION 3B: Remote Mood Filtering (INV-R11)
    // ============================================

    /// Dimensional range check + anti-tag filtering using remote mood mapping.
    /// Falls back to tag intersection for movies without emotional_profile.
    private func passesRemoteMoodFilter(movie: GWMovie, mapping: GWMoodMapping, intentTags: [String]) -> Bool {
        guard let ep = movie.emotionalProfile else {
            // No emotional profile: fall back to tag check if compatible_tags is non-empty
            if !mapping.compatibleTags.isEmpty {
                let movieTags = Set(movie.tags)
                return !movieTags.intersection(Set(mapping.compatibleTags)).isEmpty
            }
            return true // Surprise me (empty tags) -- allow through
        }

        // Check each dimension against min/max range
        if let min = mapping.targetComfortMin, (ep.comfort ?? 5) < min { return false }
        if let max = mapping.targetComfortMax, (ep.comfort ?? 5) > max { return false }
        if let min = mapping.targetDarknessMin, (ep.darkness ?? 5) < min { return false }
        if let max = mapping.targetDarknessMax, (ep.darkness ?? 5) > max { return false }
        if let min = mapping.targetEmotionalIntensityMin, (ep.emotionalIntensity ?? 5) < min { return false }
        if let max = mapping.targetEmotionalIntensityMax, (ep.emotionalIntensity ?? 5) > max { return false }
        if let min = mapping.targetEnergyMin, (ep.energy ?? 5) < min { return false }
        if let max = mapping.targetEnergyMax, (ep.energy ?? 5) > max { return false }
        if let min = mapping.targetComplexityMin, (ep.complexity ?? 5) < min { return false }
        if let max = mapping.targetComplexityMax, (ep.complexity ?? 5) > max { return false }
        if let min = mapping.targetRewatchabilityMin, (ep.rewatchability ?? 5) < min { return false }
        if let max = mapping.targetRewatchabilityMax, (ep.rewatchability ?? 5) > max { return false }
        if let min = mapping.targetHumourMin, (ep.humour ?? 5) < min { return false }
        if let max = mapping.targetHumourMax, (ep.humour ?? 5) > max { return false }
        if let min = mapping.targetMentalstimulationMin, (ep.mentalStimulation ?? 5) < min { return false }
        if let max = mapping.targetMentalstimulationMax, (ep.mentalStimulation ?? 5) > max { return false }

        // Anti-tag check: reject if movie has anti-tags
        if !mapping.antiTags.isEmpty {
            let movieTags = Set(movie.tags)
            if !movieTags.intersection(Set(mapping.antiTags)).isEmpty { return false }
        }

        return true
    }

    /// Weighted dimensional distance from ideal center across all 8 dimensions.
    /// Returns 0.0 to 1.0 where 1.0 = perfect match.
    /// Falls back to tag alignment for movies without emotional_profile.
    private func computeMoodAffinity(movie: GWMovie, mapping: GWMoodMapping, intentTags: Set<String>, tagWeights: [String: Double]) -> Double {
        guard let ep = movie.emotionalProfile else {
            // No emotional profile: fall back to tag alignment
            return computeTagAlignmentFallback(movie: movie, intentTags: intentTags, tagWeights: tagWeights)
        }

        let dimensions: [(movieVal: Double, ideal: Double, weight: Double)] = [
            (Double(ep.comfort ?? 5), mapping.idealComfort ?? 5.0, mapping.weightComfort),
            (Double(ep.darkness ?? 5), mapping.idealDarkness ?? 5.0, mapping.weightDarkness),
            (Double(ep.emotionalIntensity ?? 5), mapping.idealEmotionalIntensity ?? 5.0, mapping.weightEmotionalIntensity),
            (Double(ep.energy ?? 5), mapping.idealEnergy ?? 5.0, mapping.weightEnergy),
            (Double(ep.complexity ?? 5), mapping.idealComplexity ?? 5.0, mapping.weightComplexity),
            (Double(ep.rewatchability ?? 5), mapping.idealRewatchability ?? 5.0, mapping.weightRewatchability),
            (Double(ep.humour ?? 5), mapping.idealHumour ?? 5.0, mapping.weightHumour),
            (Double(ep.mentalStimulation ?? 5), mapping.idealMentalstimulation ?? 5.0, mapping.weightMentalstimulation),
        ]

        var totalWeightedDistance: Double = 0
        var totalWeight: Double = 0

        for dim in dimensions {
            let distance = abs(dim.movieVal - dim.ideal) / 10.0 // Normalize to 0-1
            totalWeightedDistance += distance * dim.weight
            totalWeight += dim.weight
        }

        guard totalWeight > 0 else { return 0.5 }

        let avgWeightedDistance = totalWeightedDistance / totalWeight
        let affinity = 1.0 - avgWeightedDistance
        return affinity // 0.0 to 1.0
    }

    /// Tag alignment fallback for movies without emotional_profile
    private func computeTagAlignmentFallback(movie: GWMovie, intentTags: Set<String>, tagWeights: [String: Double]) -> Double {
        let movieTags = Set(movie.tags)
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

        return totalWeight > 0 ? weightedAlignment / totalWeight : 0.0
    }

    // ============================================
    // SECTION 4: Recommendation Pipeline
    // ============================================

    /// Core recommendation: returns exactly one movie or nil with stop condition
    func recommend(from movies: [GWMovie], profile: GWUserProfileComplete) -> GWRecommendationOutput {
        if movies.isEmpty {
            return GWRecommendationOutput(movie: nil, stopCondition: .emptyCatalog)
        }

        // Filter to valid movies
        var validMovies: [GWMovie] = []
        for movie in movies {
            if case .valid = isValidMovie(movie, profile: profile) {
                validMovies.append(movie)
            }
        }

        if validMovies.isEmpty {
            let stopCondition = diagnoseStop(movies: movies, profile: profile)
            return GWRecommendationOutput(movie: nil, stopCondition: stopCondition)
        }

        // Score and sort (deterministic)
        let scored = validMovies.map { movie -> (GWMovie, Double) in
            let score = computeScore(movie: movie, profile: profile)
            return (movie, score)
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            // Tiebreaker: higher goodscore wins
            return lhs.0.goodscore > rhs.0.goodscore
        }

        // Weighted random sampling from top candidates
        // Higher-scored movies have higher probability but aren't guaranteed
        // This prevents deterministic repetition while still favoring quality
        let topN = Array(sorted.prefix(10))
        let picked = weightedRandomPick(from: topN)
        return GWRecommendationOutput(movie: picked, stopCondition: nil)
    }

    /// Recommend from raw Movie array (converts to GWMovie internally)
    func recommend(
        fromRawMovies movies: [Movie],
        profile: GWUserProfileComplete,
        contentFilter: GWNewUserContentFilter
    ) -> GWRecommendationOutput {
        let gwMovies = movies.map { GWMovie(from: $0) }.filter { movie in
            !contentFilter.shouldExclude(movie: movie)
        }
        return recommend(from: gwMovies, profile: profile)
    }

    // ============================================
    // SECTION 7: Not Tonight Logic
    // ============================================

    /// Recommend after a not_tonight rejection — avoids similar tags
    func recommendAfterNotTonight(
        from movies: [GWMovie],
        profile: GWUserProfileComplete,
        rejectedMovie: GWMovie
    ) -> GWRecommendationOutput {
        // Ensure rejected movie is excluded
        var updatedProfile = profile
        updatedProfile.notTonight.insert(rejectedMovie.id)

        // Prefer movies with different tags than the rejected one
        let rejectedTags = Set(rejectedMovie.tags)

        let validMovies = movies.filter { movie in
            if case .valid = isValidMovie(movie, profile: updatedProfile) {
                return true
            }
            return false
        }

        if validMovies.isEmpty {
            return GWRecommendationOutput(movie: nil, stopCondition: .allOptionsExhausted)
        }

        // Score with penalty for similar tags to rejected movie
        let scored = validMovies.map { movie -> (GWMovie, Double) in
            var score = computeScore(movie: movie, profile: updatedProfile)

            // Penalize movies with same tags as rejected
            let movieTags = Set(movie.tags)
            let overlap = movieTags.intersection(rejectedTags)
            let overlapPenalty = Double(overlap.count) / max(Double(movieTags.count), 1.0) * 0.3
            score -= overlapPenalty

            return (movie, score)
        }

        let sorted = scored.sorted { $0.1 > $1.1 }

        // Weighted random sampling — same as recommend() to avoid repetition
        let topN = Array(sorted.prefix(10))
        let picked = weightedRandomPick(from: topN)
        return GWRecommendationOutput(movie: picked, stopCondition: nil)
    }

    // ============================================
    // SECTION 5: Scoring
    // ============================================

    /// Compute recommendation score for a movie given a profile
    /// Score components:
    ///   - Tag alignment (50%): How well movie tags match intent, weighted by learned tag weights
    ///   - Regret safety (25%): Safe bet vs polarizing content
    ///   - Platform bias (15%): Boost movies on platforms the user historically accepts from
    ///   - Dimensional fit (10%): Penalty based on rejection dimension patterns
    ///
    /// Threshold-gated confidence boost:
    ///   When a user has enough tag weight data (≥10 tags modified from default 1.0),
    ///   the engine has higher confidence in personalization. This doesn't change the
    ///   formula weights — it amplifies the tag alignment signal by up to 10%, making
    ///   learned preferences more decisive once we have enough data to trust them.
    func computeScore(movie: GWMovie, profile: GWUserProfileComplete) -> Double {
        let movieTags = Set(movie.tags)
        let intentTags = Set(profile.intentTags)

        // 1. Mood affinity (replaces tag alignment when remote mapping available)
        let tagAlignment: Double
        if let mapping = profile.moodMapping, mapping.version > 0 {
            // Remote mood mapping: use dimensional distance scoring
            var affinity = computeMoodAffinity(movie: movie, mapping: mapping, intentTags: intentTags, tagWeights: profile.tagWeights)

            // Anti-tag penalty in scoring (not just filtering)
            if !mapping.antiTags.isEmpty {
                let antiOverlap = movieTags.intersection(Set(mapping.antiTags))
                let antiPenalty = Double(antiOverlap.count) * 0.10
                affinity = max(0, affinity - antiPenalty)
            }

            tagAlignment = affinity
        } else {
            // Fallback: original tag alignment with weights
            let intersection = movieTags.intersection(intentTags)
            var weightedAlignment = 0.0
            var totalWeight = 0.0

            for tag in intentTags {
                let weight = profile.tagWeights[tag] ?? 1.0
                totalWeight += weight
                if intersection.contains(tag) {
                    weightedAlignment += weight
                }
            }

            tagAlignment = totalWeight > 0 ? weightedAlignment / totalWeight : 0.0
        }

        // 2. Regret safety (weighted)
        let regretSafety: Double
        if movieTags.contains(RegretRisk.safe_bet.rawValue) {
            regretSafety = 1.0 * (profile.tagWeights[RegretRisk.safe_bet.rawValue] ?? 1.0)
        } else if movieTags.contains(RegretRisk.polarizing.rawValue) {
            regretSafety = 0.4 * (profile.tagWeights[RegretRisk.polarizing.rawValue] ?? 1.0)
        } else {
            regretSafety = 0.6 * (profile.tagWeights[RegretRisk.acquired_taste.rawValue] ?? 1.0)
        }

        let normalizedRegretSafety = min(max(regretSafety, 0), 1)

        // 3. Platform bias: boost movies on platforms the user tends to accept
        let platformBiasScore = computePlatformBiasScore(movie: movie, bias: profile.platformBias)

        // 4. Dimensional learning: penalize movies that match rejection patterns
        let dimensionalPenalty = computeDimensionalPenalty(movie: movie, learning: profile.dimensionalLearning)

        // 5. Taste graph score (INV-L06)
        // Normalized 0-1. Weight scales from 0% (<3 feedbacks) to 15% (20+ feedbacks).
        // Remaining weight distributed proportionally to existing components.
        // Gated by taste_engine feature flag.
        let tasteScore: Double
        let tasteWeight: Double
        if GWFeatureFlags.shared.isEnabled("taste_engine") {
            tasteScore = GWTasteEngine.shared.computeTasteScore(
                movieProfile: movie.emotionalProfile,
                tasteProfile: profile.tasteProfile,
                context: .current()
            )

            // Compute taste weight per INV-L06
            let feedbackCount = profile.tasteProfile?.totalFeedbackCount ?? 0
            if feedbackCount < 3 { tasteWeight = 0.0 }
            else if feedbackCount < 10 { tasteWeight = 0.075 }   // 7.5%
            else if feedbackCount < 20 { tasteWeight = 0.12 }    // 12%
            else { tasteWeight = 0.15 }                           // 15%
        } else {
            tasteScore = 0.0
            tasteWeight = 0.0
        }

        // Scale existing weights proportionally to make room for taste
        let existingScale = 1.0 - tasteWeight
        let baseScore = (tagAlignment * 0.50 * existingScale) +
                         (normalizedRegretSafety * 0.25 * existingScale) +
                         (platformBiasScore * 0.15 * existingScale) +
                         ((1.0 - dimensionalPenalty) * 0.10 * existingScale) +
                         (tasteScore * tasteWeight)

        // 6. Threshold-gated confidence boost
        // Once we have enough learned tag data (≥10 tags deviated from default 1.0),
        // amplify tag alignment by up to 10% to make personalization more decisive.
        // Below threshold: confidenceBoost = 0 (no effect on score).
        let confidenceBoost = computeConfidenceBoost(
            tagAlignment: tagAlignment,
            tagWeights: profile.tagWeights
        )

        return min(max(baseScore + confidenceBoost, 0), 1)
    }

    // MARK: - Confidence Boost (Threshold-Gated)

    /// Returns a small boost (0 to 0.05) to tag alignment when we have enough
    /// learned data to be confident in personalization.
    ///
    /// Activation threshold: ≥10 tags must have weights different from default (1.0).
    /// This means the user has had enough interactions for the learning system to
    /// have meaningful data. Below this threshold, returns 0 (no effect).
    ///
    /// Design: The boost scales linearly from 0 at 10 learned tags to max at 20+.
    /// Max boost is 5% of tagAlignment — enough to break ties in favor of
    /// personalized picks, but not enough to override the core scoring formula.
    private func computeConfidenceBoost(tagAlignment: Double, tagWeights: [String: Double]) -> Double {
        // Count tags that have deviated from default (1.0)
        let learnedTagCount = tagWeights.values.filter { abs($0 - 1.0) > 0.001 }.count

        // Threshold gate: need at least 10 learned tags
        let activationThreshold = 10
        guard learnedTagCount >= activationThreshold else { return 0.0 }

        // Scale factor: ramps from 0 at threshold to 1.0 at 2x threshold
        let scaleFactor = min(Double(learnedTagCount - activationThreshold) / Double(activationThreshold), 1.0)

        // Max boost: 5% of tag alignment score (breaks ties, doesn't dominate)
        let maxBoost = 0.05
        return tagAlignment * maxBoost * scaleFactor
    }

    // MARK: - Platform Bias Scoring

    /// Compute a 0-1 score based on how much the user prefers the movie's platforms
    /// Higher score = user has historically accepted more movies from this platform
    private func computePlatformBiasScore(movie: GWMovie, bias: GWPlatformBias) -> Double {
        let totalAccepts = bias.accepts.values.reduce(0, +)
        let totalRejects = bias.rejects.values.reduce(0, +)
        let totalInteractions = totalAccepts + totalRejects

        // Not enough data — return neutral 0.5
        guard totalInteractions >= 3 else { return 0.5 }

        // Find the best accept ratio among the movie's platforms
        var bestRatio = 0.0
        for platform in movie.platforms {
            let platformLower = platform.lowercased()
            let accepts = bias.accepts.first(where: { $0.key.lowercased() == platformLower })?.value ?? 0
            let rejects = bias.rejects.first(where: { $0.key.lowercased() == platformLower })?.value ?? 0
            let total = accepts + rejects
            if total > 0 {
                let ratio = Double(accepts) / Double(total)
                bestRatio = max(bestRatio, ratio)
            }
        }

        // If no platform data found, return neutral
        if bestRatio == 0.0 { return 0.5 }

        return bestRatio
    }

    // MARK: - Dimensional Learning Penalty

    /// Compute a 0-1 penalty based on rejection dimension patterns
    /// Higher penalty = movie matches dimensions the user frequently rejects for
    private func computeDimensionalPenalty(movie: GWMovie, learning: GWDimensionalLearning) -> Double {
        let totalRejections = learning.dimensions.values.reduce(0, +)

        // Not enough data — no penalty
        guard totalRejections >= 3 else { return 0.0 }

        var penalty = 0.0

        // "too_long" dimension: penalize longer movies proportionally
        if let tooLongCount = learning.dimensions[GWLearningDimension.tooLong.rawValue], tooLongCount > 0 {
            let tooLongRatio = Double(tooLongCount) / Double(totalRejections)
            // Movies over 150 min get penalized if user frequently says "too long"
            if movie.runtime > 150 {
                penalty += tooLongRatio * 0.5
            } else if movie.runtime > 120 {
                penalty += tooLongRatio * 0.2
            }
        }

        // "not_in_mood" dimension: slight penalty on mood-mismatched tags
        // This is already handled by tag weights, so apply a mild supplementary penalty
        if let notInMoodCount = learning.dimensions[GWLearningDimension.notInMood.rawValue], notInMoodCount > 0 {
            let moodRatio = Double(notInMoodCount) / Double(totalRejections)
            // If user frequently rejects for mood reasons, slightly penalize polarizing content
            if movie.tags.contains(RegretRisk.polarizing.rawValue) ||
               movie.tags.contains(RegretRisk.acquired_taste.rawValue) {
                penalty += moodRatio * 0.15
            }
        }

        // "not_interested" is handled by tag weight learning directly — no extra penalty needed

        return min(penalty, 1.0)
    }

    // MARK: - Weighted Random Selection

    /// Weighted random selection from scored candidates.
    /// Uses softmax-style exponential weighting: score differences are amplified
    /// so the top movie is ~3x more likely than #5, but #2-#4 still get picked regularly.
    /// This prevents deterministic repetition while still favoring quality.
    ///
    /// Temperature controls randomness:
    ///   - Lower = more deterministic (picks #1 almost always)
    ///   - Higher = more random (all candidates equally likely)
    ///   - 0.15 = score differences are meaningful but not absolute
    private func weightedRandomPick(from candidates: [(GWMovie, Double)]) -> GWMovie? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0].0 }

        let temperature = 0.15

        let maxScore = candidates[0].1
        let weights = candidates.map { exp(($0.1 - maxScore) / temperature) }
        let totalWeight = weights.reduce(0, +)

        let roll = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for (i, weight) in weights.enumerated() {
            cumulative += weight
            if roll < cumulative {
                return candidates[i].0
            }
        }
        return candidates.last?.0
    }

    // ============================================
    // SECTION 10: Runtime Assertions
    // ============================================

    /// Assert that a movie is valid for a profile (returns bool, no throw)
    func assertValidRecommendation(_ movie: GWMovie, profile: GWUserProfileComplete) -> Bool {
        switch isValidMovie(movie, profile: profile) {
        case .valid:
            return true
        case .invalid(let failure):
            #if DEBUG
            print("🚨 ASSERTION FAILED: \(failure.description)")
            #endif
            return false
        }
    }

    // ============================================
    // SECTION 12: Stop Condition Diagnosis
    // ============================================

    private func diagnoseStop(movies: [GWMovie], profile: GWUserProfileComplete) -> GWStopCondition {
        if movies.isEmpty {
            return .emptyCatalog
        }

        // Check if all movies are excluded
        let nonExcluded = movies.filter { !profile.allExcludedIds.contains($0.id) }
        if nonExcluded.isEmpty {
            return .allOptionsExhausted
        }

        // Check platform match
        var platformMatches: [GWMovie] = []
        if !profile.platforms.isEmpty {
            platformMatches = nonExcluded.filter { movie in
                let moviePlatforms = Set(movie.platforms.map { $0.lowercased() })
                return profile.platforms.contains { platform in
                    let p = platform.lowercased()
                    return moviePlatforms.contains { mp in
                        mp.contains(p) || p.contains(mp)
                    }
                }
            }
            if platformMatches.isEmpty {
                return .noPlatformMatch
            }
        } else {
            platformMatches = nonExcluded
        }

        // Check language match
        var languageMatches: [GWMovie] = []
        if !profile.preferredLanguages.isEmpty {
            languageMatches = nonExcluded.filter { movie in
                let movieLang = movie.language.lowercased()
                return profile.preferredLanguages.contains { lang in
                    let l = lang.lowercased()
                    return movieLang.contains(l) ||
                           (l == "english" && movieLang == "en") ||
                           (l == "hindi" && movieLang == "hi")
                }
            }
            if languageMatches.isEmpty {
                return .noLanguageMatch
            }
        } else {
            languageMatches = nonExcluded
        }

        // Check OTT + Language combination
        if !profile.platforms.isEmpty && !profile.preferredLanguages.isEmpty {
            let combinedMatches = nonExcluded.filter { movie in
                let hasPlat = profile.platforms.contains { p in
                    movie.platforms.map { $0.lowercased() }.contains { mp in
                        mp.contains(p.lowercased()) || p.lowercased().contains(mp)
                    }
                }
                let hasLang = profile.preferredLanguages.contains { l in
                    let ml = movie.language.lowercased()
                    return ml.contains(l.lowercased()) ||
                           (l.lowercased() == "english" && ml == "en") ||
                           (l.lowercased() == "hindi" && ml == "hi")
                }
                return hasPlat && hasLang
            }
            if combinedMatches.isEmpty && !platformMatches.isEmpty && !languageMatches.isEmpty {
                return .ottLanguageCombinationMismatch
            }
        }

        // Check content type
        if profile.requiresSeries {
            let seriesMovies = nonExcluded.filter { $0.isSeries }
            if seriesMovies.isEmpty {
                return .noSeriesAvailable
            }
        }

        // Check tag match
        if !profile.intentTags.isEmpty {
            let tagMatches = nonExcluded.filter { movie in
                !Set(movie.tags).intersection(Set(profile.intentTags)).isEmpty
            }
            if tagMatches.isEmpty {
                return .noTagMatch
            }
        }

        // Check goodscore threshold
        let threshold = gwGoodscoreThreshold(
            mood: profile.mood,
            timeOfDay: GWTimeOfDay.current,
            style: profile.recommendationStyle
        )
        let aboveThreshold = nonExcluded.filter { movie in
            let normalized = movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10
            return normalized >= threshold
        }
        if aboveThreshold.isEmpty {
            return .allBelowThreshold
        }

        return .noCandidatePassesValidity
    }

    // ============================================
    // Catalog Availability Check (Pre-check before recommendation)
    // ============================================

    // ============================================
    // SECTION 13: Multi-Pick Selection (Progressive Pick System)
    // ============================================

    /// Select N diverse movies from the valid candidate pool.
    /// Diversity is enforced by penalizing genre overlap with already-selected picks.
    /// Each pick must come from the top-10 at the time of selection (after diversity adjustment).
    func recommendMultiple(
        from movies: [GWMovie],
        profile: GWUserProfileComplete,
        count: Int
    ) -> [GWMovie] {
        guard count > 0 else { return [] }

        // Single pick: use standard pipeline
        if count == 1 {
            let output = recommend(from: movies, profile: profile)
            if let movie = output.movie { return [movie] }
            return []
        }

        // Try with strict profile first, then relax if not enough valid movies
        let profiles = buildProfileCascade(profile)

        var validMovies: [GWMovie] = []
        var activeProfile = profile

        for candidate in profiles {
            validMovies = []
            for movie in movies {
                if case .valid = isValidMovie(movie, profile: candidate) {
                    validMovies.append(movie)
                }
            }
            activeProfile = candidate
            #if DEBUG
            print("   recommendMultiple: \(validMovies.count) valid with profile cascade (intentTags=\(candidate.intentTags.prefix(3)), runtime=\(candidate.runtimeWindow.min)-\(candidate.runtimeWindow.max))")
            #endif
            if validMovies.count >= count { break }
        }

        guard !validMovies.isEmpty else { return [] }

        // Score all valid movies
        var scoredMovies = validMovies.map { movie -> (GWMovie, Double) in
            (movie, computeScore(movie: movie, profile: activeProfile))
        }

        var selected: [GWMovie] = []
        var selectedGenres: Set<String> = []

        for _ in 0..<count {
            guard !scoredMovies.isEmpty else { break }

            // Apply genre diversity bonus/penalty
            let adjusted = scoredMovies.map { (movie, score) -> (GWMovie, Double) in
                let movieGenres = Set(movie.genres.map { $0.lowercased() })
                let overlap = movieGenres.intersection(selectedGenres)
                let penalty = Double(overlap.count) * 0.15
                return (movie, score - penalty)
            }

            // Sort by adjusted score
            let sorted = adjusted.sorted { $0.1 > $1.1 }

            // Weighted random from top-10
            let topN = Array(sorted.prefix(10))
            guard let picked = weightedRandomPick(from: topN) else { break }

            selected.append(picked)
            selectedGenres.formUnion(picked.genres.map { $0.lowercased() })

            // Remove picked from pool
            scoredMovies.removeAll { $0.0.id == picked.id }
        }

        return selected
    }

    /// Builds a cascade of progressively relaxed profiles for multi-pick fallback.
    /// Level 0: Original profile (strict)
    /// Level 1: Expanded intent tags (add related tags)
    /// Level 2: Expanded tags + relaxed runtime (+/-15 min)
    private func buildProfileCascade(_ profile: GWUserProfileComplete) -> [GWUserProfileComplete] {
        var cascade = [profile]

        // Level 1: Expand intent tags to include related tags
        var relaxed1 = profile
        var expandedTags = Set(profile.intentTags)
        // Tag family expansion: if user wants feel_good, also accept uplifting, calm, etc.
        let tagFamilies: [String: [String]] = [
            "feel_good": ["uplifting", "calm", "light", "rewatchable"],
            "uplifting": ["feel_good", "calm", "light"],
            "dark": ["tense", "heavy", "acquired_taste"],
            "tense": ["dark", "high_energy", "full_attention"],
            "calm": ["feel_good", "light", "background_friendly", "uplifting"],
            "high_energy": ["tense", "full_attention"],
            "light": ["calm", "feel_good", "background_friendly", "rewatchable"],
            "heavy": ["dark", "full_attention", "acquired_taste"],
            "safe_bet": ["feel_good", "rewatchable", "uplifting"],
            "polarizing": ["acquired_taste", "full_attention"],
            "acquired_taste": ["polarizing", "dark", "heavy"],
        ]
        for tag in profile.intentTags {
            if let family = tagFamilies[tag] {
                expandedTags.formUnion(family)
            }
        }
        relaxed1.intentTags = Array(expandedTags)
        cascade.append(relaxed1)

        // Level 2: Also relax runtime window
        var relaxed2 = relaxed1
        relaxed2.runtimeWindow = GWRuntimeWindow(
            min: max(30, profile.runtimeWindow.min - 15),
            max: min(240, profile.runtimeWindow.max + 15)
        )
        cascade.append(relaxed2)

        return cascade
    }

    /// Convenience: recommendMultiple from raw Movie array + content filter
    func recommendMultiple(
        fromRawMovies movies: [Movie],
        profile: GWUserProfileComplete,
        contentFilter: GWNewUserContentFilter,
        count: Int
    ) -> [GWMovie] {
        let gwMovies = movies.map { GWMovie(from: $0) }.filter { !contentFilter.shouldExclude(movie: $0) }
        return recommendMultiple(from: gwMovies, profile: profile, count: count)
    }

    /// Find a replacement for a rejected card.
    /// - contrasting strategy for "Not Interested" (penalize shared tags)
    /// - similar strategy for "Already Seen" (boost shared tags)
    func findReplacement(
        from movies: [GWMovie],
        profile: GWUserProfileComplete,
        rejectedMovie: GWMovie,
        reason: GWCardRejectionReason,
        currentPicks: [GWMovie]
    ) -> GWMovie? {
        let rejectedTags = Set(rejectedMovie.tags)
        let rejectedGenres = Set(rejectedMovie.genres.map { $0.lowercased() })
        let currentIds = Set(currentPicks.map { $0.id })

        // Filter valid movies not already in current picks
        let validMovies = movies.filter { movie in
            guard !currentIds.contains(movie.id) else { return false }
            if case .valid = isValidMovie(movie, profile: profile) { return true }
            return false
        }

        guard !validMovies.isEmpty else { return nil }

        let scored = validMovies.map { movie -> (GWMovie, Double) in
            var score = computeScore(movie: movie, profile: profile)
            let movieTags = Set(movie.tags)
            let movieGenres = Set(movie.genres.map { $0.lowercased() })

            switch reason {
            case .notInterested:
                // Contrasting: penalize shared tags + genres with rejected movie
                let tagOverlap = movieTags.intersection(rejectedTags)
                let genreOverlap = movieGenres.intersection(rejectedGenres)
                score -= Double(tagOverlap.count) / max(Double(movieTags.count), 1.0) * 0.30
                score -= Double(genreOverlap.count) / max(Double(movieGenres.count), 1.0) * 0.20

            case .alreadySeen:
                // Similar: boost shared tags + genres (user likes this type)
                let tagOverlap = movieTags.intersection(rejectedTags)
                let genreOverlap = movieGenres.intersection(rejectedGenres)
                score += Double(tagOverlap.count) / max(Double(movieTags.count), 1.0) * 0.15
                score += Double(genreOverlap.count) / max(Double(movieGenres.count), 1.0) * 0.10
            }

            // Diversity penalty vs current picks
            let currentGenres = Set(currentPicks.flatMap { $0.genres.map { $0.lowercased() } })
            let overlapWithPicks = movieGenres.intersection(currentGenres)
            score -= Double(overlapWithPicks.count) * 0.05

            return (movie, score)
        }

        let sorted = scored.sorted { $0.1 > $1.1 }
        let topN = Array(sorted.prefix(10))
        return weightedRandomPick(from: topN)
    }

    func checkCatalogAvailability(
        movies: [GWMovie],
        profile: GWUserProfileComplete,
        contentFilter: GWNewUserContentFilter
    ) -> GWCatalogAvailability {
        let total = movies.count

        // Filter out content-filtered movies (animation/kids for new users)
        let filteredMovies = movies.filter { !contentFilter.shouldExclude(movie: $0) }

        #if DEBUG
        print("\n🔍 CATALOG AVAILABILITY CHECK:")
        print("   Total fetched: \(total), after content filter: \(filteredMovies.count)")
        print("   Profile platforms: \(profile.platforms)")
        print("   Profile languages: \(profile.preferredLanguages)")
        print("   Profile runtime: \(profile.runtimeWindow.min)-\(profile.runtimeWindow.max)")
        print("   Requires series: \(profile.requiresSeries)")

        // Sample: check what languages are in the fetched set
        var langDist: [String: Int] = [:]
        for m in filteredMovies { langDist[m.language, default: 0] += 1 }
        print("   Language distribution: \(langDist.sorted(by: { $0.value > $1.value }).prefix(10).map { "\($0.key):\($0.value)" }.joined(separator: ", "))")

        // Sample: check how many have platforms
        let withPlatforms = filteredMovies.filter { !$0.platforms.isEmpty }.count
        print("   Movies with OTT data: \(withPlatforms) / \(filteredMovies.count)")
        #endif

        // Helper: check if movie language matches user's preferred languages
        func languageMatch(_ movie: GWMovie) -> Bool {
            if profile.preferredLanguages.isEmpty { return true }
            let movieLang = movie.language.lowercased()
            return profile.preferredLanguages.contains { lang in
                let l = lang.lowercased()
                return movieLang.contains(l) ||
                       (l == "english" && movieLang == "en") ||
                       (l == "hindi" && movieLang == "hi") ||
                       (l == "tamil" && movieLang == "ta") ||
                       (l == "telugu" && movieLang == "te") ||
                       (l == "malayalam" && movieLang == "ml") ||
                       (l == "kannada" && movieLang == "kn") ||
                       (l == "marathi" && movieLang == "mr") ||
                       (l == "korean" && movieLang == "ko") ||
                       (l == "japanese" && movieLang == "ja") ||
                       (l == "spanish" && movieLang == "es") ||
                       (l == "french" && movieLang == "fr")
            }
        }

        // Helper: check if movie platform matches user's platforms
        func platformMatch(_ movie: GWMovie) -> Bool {
            if profile.platforms.isEmpty { return true }
            return profile.platforms.contains { platform in
                let p = platform.lowercased()
                return movie.platforms.map { $0.lowercased() }.contains { mp in
                    mp.contains(p) || p.contains(mp)
                }
            }
        }

        // Platform matches
        let platformMatches = filteredMovies.filter { platformMatch($0) }

        // Language matches
        let languageMatches = filteredMovies.filter { languageMatch($0) }

        // Runtime matches
        let runtimeMatches = filteredMovies.filter { movie in
            movie.runtime >= profile.runtimeWindow.min && movie.runtime <= profile.runtimeWindow.max
        }

        // Content type matches
        let contentTypeMatches: [GWMovie]
        if profile.requiresSeries {
            contentTypeMatches = filteredMovies.filter { $0.isSeries }
        } else {
            contentTypeMatches = filteredMovies.filter { $0.isMovie }
        }

        // Quality matches
        let qualityMatches = filteredMovies.filter { movie in
            movie.goodscore >= 7.5
        }

        // Combined: check HARD constraints only (platform + language)
        // Language is now filtered at the DB level, so language match should be ~100%.
        // Content type is also filtered at DB level.
        // Only platform matching needs client-side verification.
        let combined = filteredMovies.filter { movie in
            platformMatch(movie) && languageMatch(movie)
        }

        #if DEBUG
        print("   Platform matches: \(platformMatches.count)")
        print("   Language matches: \(languageMatches.count)")
        print("   Runtime matches: \(runtimeMatches.count)")
        print("   Content type matches: \(contentTypeMatches.count)")
        print("   Quality matches: \(qualityMatches.count)")
        print("   Combined (platform+language): \(combined.count)")
        if combined.isEmpty && !filteredMovies.isEmpty {
            // Debug: show why first 5 movies failed
            for movie in filteredMovies.prefix(5) {
                let pOk = platformMatch(movie)
                let lOk = languageMatch(movie)
                print("   ❌ \(movie.title): lang=\(movie.language)[\(lOk ? "✓" : "✗")] platforms=\(movie.platforms)[\(pOk ? "✓" : "✗")]")
            }
        }
        #endif

        // Determine issue
        var issue: GWAvailabilityIssue? = nil
        if combined.isEmpty {
            if platformMatches.isEmpty {
                issue = GWAvailabilityIssue(
                    title: "Limited Content",
                    message: "We don't have many titles available on your selected platforms. Try adding more streaming services.",
                    suggestedAction: .changePlatforms
                )
            } else if languageMatches.isEmpty {
                issue = GWAvailabilityIssue(
                    title: "Language Availability",
                    message: "Very limited content in your preferred language on these platforms. Try adding more languages.",
                    suggestedAction: .changeLanguage
                )
            } else if runtimeMatches.isEmpty {
                issue = GWAvailabilityIssue(
                    title: "Duration Mismatch",
                    message: "No titles match your selected duration. Try adjusting your time preference.",
                    suggestedAction: .changeRuntime
                )
            }
        }

        return GWCatalogAvailability(
            totalMovies: total,
            platformMatches: platformMatches.count,
            languageMatches: languageMatches.count,
            runtimeMatches: runtimeMatches.count,
            contentTypeMatches: contentTypeMatches.count,
            qualityMatches: qualityMatches.count,
            combinedMatches: combined.count,
            issue: issue
        )
    }
}

