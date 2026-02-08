import Foundation

// ============================================
// DEPRECATED - USE GWRecommendationEngine.shared.isValidMovie()
// ============================================
//
// This file exists ONLY for backwards compatibility.
// ALL filtering MUST go through GWRecommendationEngine.
//
// The isEligible function below is a FACADE that delegates
// to the canonical validation logic.
//
// DO NOT add filtering logic here.
// DO NOT bypass the engine.
// ============================================

struct MovieFilter {
    /// DEPRECATED: Use GWRecommendationEngine.shared.isValidMovie() directly.
    /// This method is a facade for backwards compatibility.
    @available(*, deprecated, message: "Use GWRecommendationEngine.shared.isValidMovie() instead")
    static func isEligible(_ m: Movie, ctx: UserContext) -> Bool {
        // Convert to canonical types and delegate
        let gwMovie = GWMovie(from: m)
        let profile = GWUserProfileComplete.from(context: ctx, userId: "anonymous", excludedIds: [])

        let result = GWRecommendationEngine.shared.isValidMovie(gwMovie, profile: profile)

        switch result {
        case .valid:
            return true
        case .invalid(let failure):
            #if DEBUG
            print("❌ MovieFilter.isEligible rejected \(m.title): \(failure.description)")
            #endif
            return false
        }
    }

    /// Helper to convert OTTPlatform to provider name variations
    /// DEPRECATED: Use GWRecommendationEngine's internal platform matching
    @available(*, deprecated, message: "Use GWRecommendationEngine")
    static func platformToProviderNames(_ platform: OTTPlatform) -> [String] {
        switch platform {
        case .jioHotstar:
            return ["jiohotstar", "hotstar", "disney+ hotstar"]
        case .prime:
            return ["amazon prime video", "amazon prime video with ads", "amazon video"]
        case .netflix:
            return ["netflix", "netflix kids"]
        case .sonyLIV:
            return ["sony liv", "sonyliv"]
        case .zee5:
            return ["zee5"]
        case .appleTV:
            return ["apple tv", "apple tv+"]
        }
    }
}

// ============================================
// SECTION 6: LANGUAGE ENFORCEMENT ASSERTIONS
// ============================================
//
// These assertions ensure language filtering cannot be bypassed.
// They are checked at multiple points in the recommendation flow.
// ============================================

/// Runtime assertion for language matching.
/// CRASHES in DEBUG if a movie's language doesn't match user preferences.
/// In PROD, logs error but continues (fail-open for availability).
func assertLanguageMatch(movie: Movie, userLanguages: [Language]) {
    guard !userLanguages.isEmpty else { return }

    let movieLang = (movie.original_language ?? "").lowercased()
    let userLangs = userLanguages.map { $0.rawValue.lowercased() }

    let match = userLangs.contains { lang in
        movieLang.contains(lang) ||
        (lang == "english" && movieLang == "en") ||
        (lang == "hindi" && movieLang == "hi")
    }

    if !match {
        let message = """
        🚨 LANGUAGE ASSERTION FAILED
        Movie: \(movie.title)
        Movie Language: \(movie.original_language ?? "nil")
        User Languages: \(userLanguages.map { $0.rawValue })

        This movie should NEVER have reached this point.
        Check GWRecommendationEngine.isValidMovie() implementation.
        """

        #if DEBUG
        // In DEBUG, crash immediately to catch the bug
        fatalError(message)
        #else
        // In PROD, log error for investigation
        print(message)
        // TODO: Send to error tracking service
        #endif
    }
}

/// Asserts platform matching - movie must be available on user's platforms
func assertPlatformMatch(movie: Movie, userPlatforms: [OTTPlatform]) {
    guard !userPlatforms.isEmpty else { return }

    guard let providers = movie.ott_providers, !providers.isEmpty else {
        #if DEBUG
        fatalError("PLATFORM ASSERTION FAILED: Movie \(movie.title) has no OTT providers")
        #else
        print("🚨 PLATFORM ASSERTION FAILED: Movie \(movie.title) has no OTT providers")
        return
        #endif
    }

    let moviePlatformNames = Set(providers.map { $0.name.lowercased() })

    var hasMatch = false
    for platform in userPlatforms {
        let variations = MovieFilter.platformToProviderNames(platform)
        for variation in variations {
            if moviePlatformNames.contains(where: { $0.contains(variation) }) {
                hasMatch = true
                break
            }
        }
        if hasMatch { break }
    }

    if !hasMatch {
        let message = """
        🚨 PLATFORM ASSERTION FAILED
        Movie: \(movie.title)
        Movie Platforms: \(moviePlatformNames)
        User Platforms: \(userPlatforms.map { $0.rawValue })

        This movie should NEVER have reached this point.
        Check GWRecommendationEngine.isValidMovie() implementation.
        """

        #if DEBUG
        fatalError(message)
        #else
        print(message)
        #endif
    }
}

/// Asserts that a movie hasn't been rejected before
func assertNotRejected(movieId: UUID, rejectedIds: Set<UUID>) {
    if rejectedIds.contains(movieId) {
        let message = """
        🚨 REPEAT MOVIE ASSERTION FAILED
        Movie ID: \(movieId)
        This movie was previously rejected and should NEVER resurface.

        Check exclusion logic in GWRecommendationEngine.
        """

        #if DEBUG
        fatalError(message)
        #else
        print(message)
        #endif
    }
}
