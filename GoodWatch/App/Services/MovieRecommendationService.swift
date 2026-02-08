import Foundation

// ============================================
// MovieRecommendationService - FACADE for GWRecommendationEngine
// ============================================
//
// This service is a FACADE that delegates ALL logic to GWRecommendationEngine.
// It handles caching and async operations but NO filtering/scoring logic.
//
// ALL recommendation logic lives in GWRecommendationEngine.
// DO NOT add filtering/sorting/selection logic here.
// ============================================

final class MovieRecommendationService {
    static let shared = MovieRecommendationService()
    private init() {}

    private var cachedMovies: [Movie] = []
    private var lastFetchTime: Date?
    private let cacheValidityMinutes: Double = 30
    private let engine = GWRecommendationEngine.shared

    // MARK: - Get Next Recommendation

    /// Get next recommendation using canonical engine.
    /// All filtering/scoring delegated to GWRecommendationEngine.
    ///
    /// NEW USER CONTENT FILTER:
    /// - Documentaries are filtered out for new users (< 5 watch_now interactions)
    /// - Unless user has explicitly picked a documentary before
    func getNextRecommendation(
        userId: UUID,
        profile: GWUserProfile,
        excludeMovieIds: Set<UUID> = []
    ) async throws -> Movie? {

        // Fetch movies if cache is stale
        if shouldRefreshCache() {
            try await refreshMovieCache()
        }

        // Get rejection lists from Supabase
        let permanentRejections = try await InteractionService.shared.getRejectedMovieIds(userId: userId)
        let recentRejections = try await InteractionService.shared.getRecentlyRejectedMovieIds(userId: userId)
        let allExclusions = permanentRejections.union(recentRejections).union(excludeMovieIds)

        // Get user maturity info for content filtering
        let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userId)
        let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

        #if DEBUG
        print("👤 User maturity: \(maturityInfo.watchNowCount) watch_now, documentary pref: \(maturityInfo.hasWatchedDocumentary), show docs: \(contentFilter.shouldShowDocumentaries)")
        #endif

        // Convert to canonical profile
        let canonicalProfile = buildCanonicalProfile(
            from: profile,
            userId: userId.uuidString,
            excludedIds: allExclusions.map { $0.uuidString }
        )

        // Use canonical engine with content filter
        let output = engine.recommend(fromRawMovies: cachedMovies, profile: canonicalProfile, contentFilter: contentFilter)

        // Get original Movie object
        guard let gwMovie = output.movie else {
            #if DEBUG
            if let condition = output.stopCondition {
                print("⚠️ No recommendation: \(condition.description)")
            }
            #endif
            return nil
        }

        let result = cachedMovies.first { $0.id.uuidString == gwMovie.id }

        // Validate result (Section 10: Runtime assertions)
        if let movie = result {
            let isValid = engine.assertValidRecommendation(
                GWMovie(from: movie),
                profile: canonicalProfile
            )
            if !isValid {
                return nil
            }
        }

        return result
    }

    // MARK: - Get Next After Rejection (Section 7)

    func getNextAfterRejection(
        userId: UUID,
        profile: GWUserProfile,
        rejectedMovieId: UUID,
        rejectionReason: String?
    ) async throws -> Movie? {

        // Fetch fresh if needed
        if shouldRefreshCache() {
            try await refreshMovieCache()
        }

        // Get all exclusions
        let permanentRejections = try await InteractionService.shared.getRejectedMovieIds(userId: userId)
        let recentRejections = try await InteractionService.shared.getRecentlyRejectedMovieIds(userId: userId)
        var allExclusions = permanentRejections.union(recentRejections)
        allExclusions.insert(rejectedMovieId)

        // Get rejected movie for Section 7 logic
        guard let rejectedMovie = cachedMovies.first(where: { $0.id == rejectedMovieId }) else {
            // If rejected movie not found, fall back to regular recommendation
            return try await getNextRecommendation(
                userId: userId,
                profile: profile,
                excludeMovieIds: allExclusions
            )
        }

        // Get user maturity info for content filtering
        let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userId)
        let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

        // Convert to canonical profile
        let canonicalProfile = buildCanonicalProfile(
            from: profile,
            userId: userId.uuidString,
            excludedIds: allExclusions.map { $0.uuidString }
        )

        // Filter movies for new users before Section 7 logic
        let gwMovies = cachedMovies.map { GWMovie(from: $0) }.filter { movie in
            !contentFilter.shouldExclude(movie: movie)
        }

        // Use Section 7 logic in engine
        let gwRejected = GWMovie(from: rejectedMovie)
        let output = engine.recommendAfterNotTonight(
            from: gwMovies,
            profile: canonicalProfile,
            rejectedMovie: gwRejected
        )

        guard let gwMovie = output.movie else {
            return nil
        }

        return cachedMovies.first { $0.id.uuidString == gwMovie.id }
    }

    // MARK: - Get Similar But Unseen

    func getSimilarButUnseen(
        userId: UUID,
        profile: GWUserProfile,
        seenMovieId: UUID
    ) async throws -> Movie? {

        if shouldRefreshCache() {
            try await refreshMovieCache()
        }

        guard let seenMovie = cachedMovies.first(where: { $0.id == seenMovieId }) else {
            return try await getNextRecommendation(userId: userId, profile: profile)
        }

        // Get exclusions
        let permanentRejections = try await InteractionService.shared.getRejectedMovieIds(userId: userId)
        let recentRejections = try await InteractionService.shared.getRecentlyRejectedMovieIds(userId: userId)
        var allExclusions = permanentRejections.union(recentRejections)
        allExclusions.insert(seenMovieId)

        // Get user maturity info for content filtering
        let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userId)
        let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

        // Build profile with tags from seen movie for similarity
        var canonicalProfile = buildCanonicalProfile(
            from: profile,
            userId: userId.uuidString,
            excludedIds: allExclusions.map { $0.uuidString }
        )

        // Add tags from seen movie to intent for similarity
        let seenTags = GWMovie(from: seenMovie).tags
        var newIntentTags = Set(canonicalProfile.intentTags)
        for tag in seenTags {
            if TagTaxonomy.isValidTag(tag) {
                newIntentTags.insert(tag)
            }
        }
        canonicalProfile = GWUserProfileComplete(
            userId: canonicalProfile.userId,
            preferredLanguages: canonicalProfile.preferredLanguages,
            platforms: canonicalProfile.platforms,
            runtimeWindow: canonicalProfile.runtimeWindow,
            mood: canonicalProfile.mood,
            intentTags: Array(newIntentTags),
            seen: canonicalProfile.seen,
            notTonight: canonicalProfile.notTonight,
            abandoned: canonicalProfile.abandoned,
            recommendationStyle: canonicalProfile.recommendationStyle,
            tagWeights: canonicalProfile.tagWeights
        )

        let output = engine.recommend(fromRawMovies: cachedMovies, profile: canonicalProfile, contentFilter: contentFilter)

        guard let gwMovie = output.movie else {
            return nil
        }

        return cachedMovies.first { $0.id.uuidString == gwMovie.id }
    }

    // MARK: - GoodScore (DEPRECATED - Use engine directly)

    /// DEPRECATED: GoodScore is now computed by GWRecommendationEngine.
    /// This method exists only for backwards compatibility.
    @available(*, deprecated, message: "Use GWRecommendationEngine.shared.computeScore()")
    func calculateGoodScore(
        movie: Movie,
        profile: GWUserProfile,
        confidenceLevel: Double
    ) -> Double {
        let gwMovie = GWMovie(from: movie)
        let canonicalProfile = buildCanonicalProfile(
            from: profile,
            userId: "anonymous",
            excludedIds: []
        )
        return engine.computeScore(movie: gwMovie, profile: canonicalProfile) * 100
    }

    // MARK: - Private Helpers

    private func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        let elapsed = Date().timeIntervalSince(lastFetch)
        return elapsed > (cacheValidityMinutes * 60)
    }

    private func refreshMovieCache() async throws {
        cachedMovies = try await SupabaseService.shared.fetchMovies(limit: 1000)
        lastFetchTime = Date()
        #if DEBUG
        print("📦 Refreshed movie cache: \(cachedMovies.count) movies")
        #endif
    }

    /// Build canonical profile from GWUserProfile
    private func buildCanonicalProfile(
        from profile: GWUserProfile,
        userId: String,
        excludedIds: [String]
    ) -> GWUserProfileComplete {
        GWUserProfileComplete(
            userId: userId,
            preferredLanguages: profile.preferred_languages,
            platforms: profile.platforms,
            runtimeWindow: GWRuntimeWindow(
                min: 60,
                max: profile.runtime_preferences.max_runtime
            ),
            mood: profile.mood_preferences.current_mood ?? "neutral",
            intentTags: ["safe_bet", "feel_good"], // Default safe tags
            seen: [],
            notTonight: Set(excludedIds),
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: TagWeightStore.shared.getWeights()
        )
    }
}
