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
        requiresSeries: Bool = false
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
    }

    /// Build from UserContext (used in EmotionalHookView and MovieFilter)
    static func from(context: UserContext, userId: String, excludedIds: [String]) -> GWUserProfileComplete {
        GWUserProfileComplete(
            userId: userId,
            preferredLanguages: context.languages.map { $0.rawValue },
            platforms: context.otts.map { $0.rawValue },
            runtimeWindow: GWRuntimeWindow(min: context.minDuration, max: context.maxDuration),
            mood: context.mood.rawValue,
            intentTags: context.intent.intent_tags,
            seen: [],
            notTonight: Set(excludedIds),
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: TagWeightStore.shared.getWeights(),
            requiresSeries: context.requiresSeries
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

        // Rule 5: Content type match (if user requires series)
        if profile.requiresSeries {
            if !movie.isSeries {
                return .invalid(.contentTypeMismatch(expected: "series", actual: movie.contentType))
            }
        }

        // Rule 6: GoodScore threshold
        // If composite_score is available (> 0), prefer it for the threshold check
        let threshold = gwGoodscoreThreshold(
            mood: profile.mood,
            timeOfDay: GWTimeOfDay.current,
            style: profile.recommendationStyle
        )
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

        // Rule 7: Tag intersection
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

        return .valid
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

        return GWRecommendationOutput(movie: sorted.first?.0, stopCondition: nil)
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
        return GWRecommendationOutput(movie: sorted.first?.0, stopCondition: nil)
    }

    // ============================================
    // SECTION 5: Scoring
    // ============================================

    /// Compute recommendation score for a movie given a profile
    func computeScore(movie: GWMovie, profile: GWUserProfileComplete) -> Double {
        let movieTags = Set(movie.tags)
        let intentTags = Set(profile.intentTags)

        // Tag alignment with weights
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

        let tagAlignment = totalWeight > 0 ? weightedAlignment / totalWeight : 0.0

        // Regret safety (weighted)
        let regretSafety: Double
        if movieTags.contains(RegretRisk.safe_bet.rawValue) {
            regretSafety = 1.0 * (profile.tagWeights[RegretRisk.safe_bet.rawValue] ?? 1.0)
        } else if movieTags.contains(RegretRisk.polarizing.rawValue) {
            regretSafety = 0.4 * (profile.tagWeights[RegretRisk.polarizing.rawValue] ?? 1.0)
        } else {
            regretSafety = 0.6 * (profile.tagWeights[RegretRisk.acquired_taste.rawValue] ?? 1.0)
        }

        let normalizedRegretSafety = min(max(regretSafety, 0), 1)

        return (tagAlignment * 0.6) + (normalizedRegretSafety * 0.4)
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

    func checkCatalogAvailability(
        movies: [GWMovie],
        profile: GWUserProfileComplete,
        contentFilter: GWNewUserContentFilter
    ) -> GWCatalogAvailability {
        let total = movies.count

        // Filter out content-filtered movies
        let filteredMovies = movies.filter { !contentFilter.shouldExclude(movie: $0) }

        // Platform matches
        let platformMatches = filteredMovies.filter { movie in
            if profile.platforms.isEmpty { return true }
            return profile.platforms.contains { platform in
                let p = platform.lowercased()
                return movie.platforms.map { $0.lowercased() }.contains { mp in
                    mp.contains(p) || p.contains(mp)
                }
            }
        }

        // Language matches
        let languageMatches = filteredMovies.filter { movie in
            if profile.preferredLanguages.isEmpty { return true }
            let movieLang = movie.language.lowercased()
            return profile.preferredLanguages.contains { lang in
                let l = lang.lowercased()
                return movieLang.contains(l) ||
                       (l == "english" && movieLang == "en") ||
                       (l == "hindi" && movieLang == "hi")
            }
        }

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

        // Combined: all filters
        let combined = filteredMovies.filter { movie in
            if case .valid = isValidMovie(movie, profile: profile) {
                return true
            }
            return false
        }

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

