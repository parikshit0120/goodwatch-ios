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
            return nil
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
