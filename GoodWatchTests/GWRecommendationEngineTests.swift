import XCTest
@testable import GoodWatch

// ============================================
// SECTION 11: DETERMINISTIC TEST HARNESS (MANDATORY)
//
// Tests MUST:
// - Use fixed fixtures
// - Have zero randomness
// - Pass before UI integration
// - Verify ALL 12 sections of the spec
// ============================================

final class GWRecommendationEngineTests: XCTestCase {

    // MARK: - Test Engine Instance
    private let engine = GWRecommendationEngine.shared

    // MARK: - Fixed Test Fixtures (Zero Randomness)

    /// English movie on Netflix with safe_bet tag
    static let englishNetflixMovie = GWMovie(
        id: "test-movie-001",
        title: "English Netflix Movie",
        year: 2023,
        runtime: 120,
        language: "en",
        platforms: ["netflix"],
        poster_url: nil,
        overview: "A test movie",
        genres: ["Drama"],
        tags: ["medium", "safe_bet", "full_attention", "calm", "feel_good"],
        goodscore: 85.0,
        available: true
    )

    /// Hindi movie on Hotstar with safe_bet tag
    static let hindiHotstarMovie = GWMovie(
        id: "test-movie-002",
        title: "Hindi Hotstar Movie",
        year: 2022,
        runtime: 150,
        language: "hi",
        platforms: ["jio_hotstar"],
        poster_url: nil,
        overview: "A Hindi test movie",
        genres: ["Comedy"],
        tags: ["light", "safe_bet", "background_friendly", "calm", "feel_good"],
        goodscore: 82.0,
        available: true
    )

    /// Low score movie (below threshold)
    static let lowScoreMovie = GWMovie(
        id: "test-movie-003",
        title: "Low Score Movie",
        year: 2021,
        runtime: 100,
        language: "en",
        platforms: ["netflix", "prime"],
        poster_url: nil,
        overview: "A low score movie",
        genres: ["Action"],
        tags: ["heavy", "polarizing", "full_attention", "high_energy", "dark"],
        goodscore: 65.0,
        available: true
    )

    /// High score movie for late night (needs 85+)
    static let lateNightMovie = GWMovie(
        id: "test-movie-004",
        title: "Late Night Quality Movie",
        year: 2023,
        runtime: 110,
        language: "en",
        platforms: ["netflix"],
        poster_url: nil,
        overview: "A high quality movie for late night",
        genres: ["Drama"],
        tags: ["light", "safe_bet", "rewatchable", "calm", "feel_good"],
        goodscore: 88.0,
        available: true
    )

    /// Movie with acquired_taste tag (high risk)
    static let acquiredTasteMovie = GWMovie(
        id: "test-movie-005",
        title: "Acquired Taste Film",
        year: 2020,
        runtime: 140,
        language: "en",
        platforms: ["prime"],
        poster_url: nil,
        overview: "An artsy film",
        genres: ["Drama", "Art House"],
        tags: ["heavy", "acquired_taste", "full_attention", "tense", "dark"],
        goodscore: 82.0,
        available: true
    )

    /// Unavailable movie (no OTT providers)
    static let unavailableMovie = GWMovie(
        id: "test-movie-006",
        title: "Unavailable Movie",
        year: 2023,
        runtime: 100,
        language: "en",
        platforms: [],
        poster_url: nil,
        overview: "No streaming available",
        genres: ["Drama"],
        tags: ["safe_bet", "feel_good"],
        goodscore: 90.0,
        available: false
    )

    // MARK: - User Profiles

    static func hindiOnlyProfile() -> GWUserProfileComplete {
        GWUserProfileComplete(
            userId: "test-user-hindi",
            preferredLanguages: ["hindi"],
            platforms: ["jio_hotstar", "zee5"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )
    }

    static func englishOnlyProfile() -> GWUserProfileComplete {
        GWUserProfileComplete(
            userId: "test-user-english",
            preferredLanguages: ["english"],
            platforms: ["netflix", "prime"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )
    }

    static func multiLanguageProfile() -> GWUserProfileComplete {
        GWUserProfileComplete(
            userId: "test-user-multi",
            preferredLanguages: ["english", "hindi"],
            platforms: ["netflix", "prime", "jio_hotstar"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )
    }

    // ============================================
    // SECTION 1: isValidMovie Tests
    // ============================================

    // MARK: - Test: Language Enforcement (CRITICAL - Spec Bug Fix)

    func testNeverShowsEnglishMovieToHindiOnlyUser() {
        // Given: Hindi-only user and English movie
        let profile = Self.hindiOnlyProfile()
        let movie = Self.englishNetflixMovie

        // When: Validating the movie using canonical engine
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with language mismatch
        if case .invalid(let failure) = result {
            if case .languageMismatch = failure {
                // Expected - test passes
            } else {
                XCTFail("Expected languageMismatch, got: \(failure)")
            }
        } else {
            XCTFail("English movie should NOT be valid for Hindi-only user")
        }
    }

    func testNeverShowsHindiMovieToEnglishOnlyUser() {
        // Given: English-only user and Hindi movie
        let profile = Self.englishOnlyProfile()
        let movie = Self.hindiHotstarMovie

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with language mismatch
        if case .invalid(let failure) = result {
            if case .languageMismatch = failure {
                // Expected
            } else {
                XCTFail("Expected languageMismatch, got: \(failure)")
            }
        } else {
            XCTFail("Hindi movie should NOT be valid for English-only user")
        }
    }

    func testAcceptsBothLanguagesForMultiLanguageUser() {
        // Given: Multi-language user
        let profile = Self.multiLanguageProfile()

        // When: Validating English and Hindi movies
        let englishResult = engine.isValidMovie(Self.englishNetflixMovie, profile: profile)
        let hindiResult = engine.isValidMovie(Self.hindiHotstarMovie, profile: profile)

        // Then: Both should pass language check (may fail on other rules)
        // We just verify they don't fail on language specifically
        if case .invalid(.languageMismatch) = englishResult {
            XCTFail("English movie should pass language check for multi-language user")
        }
        if case .invalid(.languageMismatch) = hindiResult {
            XCTFail("Hindi movie should pass language check for multi-language user")
        }
    }

    // MARK: - Test: Platform Enforcement

    func testRejectsMovieOnWrongPlatform() {
        // Given: Netflix-only user and Hotstar movie
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: ["english", "hindi"], // Accept any language
            platforms: ["netflix"], // Only Netflix
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: profile.notTonight,
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        let movie = Self.hindiHotstarMovie // On jio_hotstar only

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with platform mismatch
        if case .invalid(let failure) = result {
            if case .platformMismatch = failure {
                // Expected
            } else {
                XCTFail("Expected platformMismatch, got: \(failure)")
            }
        } else {
            XCTFail("Hotstar movie should NOT be valid for Netflix-only user")
        }
    }

    // MARK: - Test: Repeat Prevention (Section 8)

    func testNeverResurfacesNotTonightMovie() {
        // Given: User who rejected a movie
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: [Self.englishNetflixMovie.id], // Rejected this movie
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        // When: Validating the rejected movie
        let result = engine.isValidMovie(Self.englishNetflixMovie, profile: profile)

        // Then: Should fail with already interacted
        if case .invalid(let failure) = result {
            if case .alreadyInteracted = failure {
                // Expected
            } else {
                XCTFail("Expected alreadyInteracted, got: \(failure)")
            }
        } else {
            XCTFail("Rejected movie should NOT be valid")
        }
    }

    func testNeverResurfacesSeenMovie() {
        // Given: User who has seen a movie
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: [Self.englishNetflixMovie.id], // Already seen
            notTonight: profile.notTonight,
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        // When: Validating
        let result = engine.isValidMovie(Self.englishNetflixMovie, profile: profile)

        // Then: Should fail
        if case .invalid(let failure) = result {
            if case .alreadyInteracted = failure {
                // Expected
            } else {
                XCTFail("Expected alreadyInteracted, got: \(failure)")
            }
        } else {
            XCTFail("Seen movie should NOT be valid")
        }
    }

    func testNeverResurfacesAbandonedMovie() {
        // Given: User who abandoned a movie
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: profile.notTonight,
            abandoned: [Self.englishNetflixMovie.id], // Abandoned
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        // When: Validating
        let result = engine.isValidMovie(Self.englishNetflixMovie, profile: profile)

        // Then: Should fail
        if case .invalid(let failure) = result {
            if case .alreadyInteracted = failure {
                // Expected
            } else {
                XCTFail("Expected alreadyInteracted, got: \(failure)")
            }
        } else {
            XCTFail("Abandoned movie should NOT be valid")
        }
    }

    // MARK: - Test: Runtime Window

    func testRejectsMovieOutsideRuntimeWindow() {
        // Given: User with short runtime preference
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: GWRuntimeWindow(min: 60, max: 100), // Max 100 minutes
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: profile.notTonight,
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        let movie = Self.englishNetflixMovie // 120 minutes

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with runtime violation
        if case .invalid(let failure) = result {
            if case .runtimeOutOfWindow = failure {
                // Expected
            } else {
                XCTFail("Expected runtimeOutOfWindow, got: \(failure)")
            }
        } else {
            XCTFail("120 min movie should NOT be valid for 100 min max user")
        }
    }

    // MARK: - Test: GoodScore as Gate (Section 5)

    func testRejectsMovieBelowGoodscoreThreshold() {
        // Given: User in neutral mood (threshold = 75)
        let profile = Self.englishOnlyProfile()
        let movie = Self.lowScoreMovie // goodscore: 65

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with goodscore violation
        if case .invalid(let failure) = result {
            if case .goodscoreBelowThreshold = failure {
                // Expected
            } else {
                XCTFail("Expected goodscoreBelowThreshold, got: \(failure)")
            }
        } else {
            XCTFail("Low score movie (65) should NOT be valid (threshold 75)")
        }
    }

    func testAcceptsMovieAboveGoodscoreThreshold() {
        // Given: Movie with high score
        let profile = Self.englishOnlyProfile()
        let movie = Self.englishNetflixMovie // goodscore: 85

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should pass (85 >= 75)
        if case .invalid(let failure) = result {
            if case .goodscoreBelowThreshold = failure {
                XCTFail("Movie with score 85 should pass threshold 75")
            }
            // Other failures are OK (e.g., tag mismatch)
        }
    }

    // MARK: - Test: Tag Intersection (Section 6)

    func testRejectsMovieWithNoMatchingTags() {
        // Given: User wanting high_energy, dark
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: ["high_energy", "dark"], // Specific intent
            seen: profile.seen,
            notTonight: profile.notTonight,
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        // Movie with calm, feel_good tags (no overlap)
        let movie = Self.englishNetflixMovie

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with tag violation
        if case .invalid(let failure) = result {
            if case .noMatchingTags = failure {
                // Expected
            } else {
                XCTFail("Expected noMatchingTags, got: \(failure)")
            }
        } else {
            XCTFail("Calm movie should NOT match high_energy/dark intent")
        }
    }

    // MARK: - Test: Unavailable Movie

    func testRejectsUnavailableMovie() {
        // Given: Movie with no OTT providers
        let profile = Self.englishOnlyProfile()
        let movie = Self.unavailableMovie

        // When: Validating
        let result = engine.isValidMovie(movie, profile: profile)

        // Then: Should fail with unavailable
        if case .invalid(let failure) = result {
            if case .movieUnavailable = failure {
                // Expected
            } else {
                XCTFail("Expected movieUnavailable, got: \(failure)")
            }
        } else {
            XCTFail("Unavailable movie should NOT be valid")
        }
    }

    // ============================================
    // SECTION 4: Deterministic Recommendation Pipeline
    // ============================================

    func testRecommendReturnsNilWhenNoValidMovieExists() {
        // Given: Impossible criteria
        let profile = GWUserProfileComplete(
            userId: "impossible-user",
            preferredLanguages: ["esperanto"], // No movies in this language
            platforms: ["nonexistent_platform"],
            runtimeWindow: GWRuntimeWindow(min: 1, max: 10), // Too short
            mood: "neutral",
            intentTags: ["safe_bet"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishNetflixMovie, Self.hindiHotstarMovie]

        // When: Recommending
        let output = engine.recommend(from: movies, profile: profile)

        // Then: Should return nil
        XCTAssertNil(output.movie, "Should return nil when no valid movie exists")
        XCTAssertNotNil(output.stopCondition, "Should have a stop condition")
    }

    func testRecommendReturnsSingleValidMovie() {
        // Given: Valid profile and movies
        let profile = Self.englishOnlyProfile()
        let movies = [
            Self.englishNetflixMovie,
            Self.hindiHotstarMovie, // Will be filtered (language)
            Self.lowScoreMovie, // Will be filtered (score)
        ]

        // When: Recommending
        let output = engine.recommend(from: movies, profile: profile)

        // Then: Should return exactly one movie
        XCTAssertNotNil(output.movie, "Should return a movie")
        XCTAssertEqual(output.movie?.id, Self.englishNetflixMovie.id, "Should return the valid English movie")
    }

    func testRecommendIsDeterministic() {
        // Given: Fixed inputs
        let profile = Self.englishOnlyProfile()
        let movies = [Self.englishNetflixMovie, Self.lateNightMovie]

        // When: Running recommendation multiple times
        let output1 = engine.recommend(from: movies, profile: profile)
        let output2 = engine.recommend(from: movies, profile: profile)
        let output3 = engine.recommend(from: movies, profile: profile)

        // Then: All results should be identical (deterministic)
        XCTAssertEqual(output1.movie?.id, output2.movie?.id, "First two should match")
        XCTAssertEqual(output2.movie?.id, output3.movie?.id, "Second two should match")
    }

    // ============================================
    // SECTION 5: GoodScore Threshold Varies
    // ============================================

    func testThresholdHigherAtLateNight() {
        // Given: Late night time
        let threshold = gwGoodscoreThreshold(mood: "neutral", timeOfDay: .lateNight, style: .safe)

        // Then: Should be 85 or higher
        XCTAssertGreaterThanOrEqual(threshold, 85.0, "Late night threshold should be at least 85")
    }

    func testThresholdHigherWhenTired() {
        // Given: Tired mood
        let threshold = gwGoodscoreThreshold(mood: "tired", timeOfDay: .evening, style: .safe)

        // Then: Should be 88 (highest)
        XCTAssertEqual(threshold, 88.0, "Tired mood should have threshold 88")
    }

    func testThresholdLowerForAdventurous() {
        // Given: Adventurous style
        let threshold = gwGoodscoreThreshold(mood: "neutral", timeOfDay: .evening, style: .adventurous)

        // Then: Should be 70 (lowest)
        XCTAssertEqual(threshold, 70.0, "Adventurous style should have threshold 70")
    }

    // ============================================
    // SECTION 7: Not Tonight Logic
    // ============================================

    func testRecommendAfterNotTonightExcludesRejectedMovie() {
        // Given: User rejected a movie
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: [Self.englishNetflixMovie.id], // Already rejected
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        let movies = [Self.englishNetflixMovie, Self.lateNightMovie]

        // When: Getting next recommendation
        let output = engine.recommendAfterNotTonight(
            from: movies,
            profile: profile,
            rejectedMovie: Self.englishNetflixMovie
        )

        // Then: Should not return the rejected movie
        XCTAssertNotEqual(output.movie?.id, Self.englishNetflixMovie.id, "Should not return rejected movie")
        // Should return the other valid movie
        XCTAssertEqual(output.movie?.id, Self.lateNightMovie.id, "Should return alternate movie")
    }

    // ============================================
    // SECTION 9: Feedback Loop - Tag Weights
    // ============================================

    func testTagWeightsAffectScoring() {
        // Given: Two movies with different tags
        let safeBetMovie = Self.englishNetflixMovie // Has safe_bet
        let darkMovie = Self.acquiredTasteMovie // Has dark, acquired_taste

        // Profile that strongly prefers safe_bet
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: ["netflix", "prime"], // Both platforms
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: ["safe_bet"], // Wants safe_bet
            seen: profile.seen,
            notTonight: profile.notTonight,
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: ["safe_bet": 2.0, "acquired_taste": 0.3] // Strong preference
        )

        // When: Computing scores
        let safeBetScore = engine.computeScore(movie: safeBetMovie, profile: profile)
        let darkScore = engine.computeScore(movie: darkMovie, profile: profile)

        // Then: safe_bet movie should score higher
        XCTAssertGreaterThan(safeBetScore, darkScore, "safe_bet movie should score higher with weighted preference")
    }

    // ============================================
    // SECTION 10: Runtime Assertions
    // ============================================

    func testAssertValidRecommendationReturnsFalseForInvalidMovie() {
        // Given: Invalid movie for user
        let profile = Self.hindiOnlyProfile()
        let movie = Self.englishNetflixMovie // Wrong language

        // When: Asserting validity
        let isValid = engine.assertValidRecommendation(movie, profile: profile)

        // Then: Should return false
        XCTAssertFalse(isValid, "Should return false for invalid movie")
    }

    func testAssertValidRecommendationReturnsTrueForValidMovie() {
        // Given: Valid movie for user
        let profile = Self.englishOnlyProfile()
        let movie = Self.englishNetflixMovie

        // When: Asserting validity
        let isValid = engine.assertValidRecommendation(movie, profile: profile)

        // Then: Should return true
        XCTAssertTrue(isValid, "Should return true for valid movie")
    }

    // ============================================
    // SECTION 12: Stop Conditions
    // ============================================

    func testStopConditionWhenAllOptionsExhausted() {
        // Given: All movies are excluded
        var profile = Self.englishOnlyProfile()
        profile = GWUserProfileComplete(
            userId: profile.userId,
            preferredLanguages: profile.preferredLanguages,
            platforms: profile.platforms,
            runtimeWindow: profile.runtimeWindow,
            mood: profile.mood,
            intentTags: profile.intentTags,
            seen: profile.seen,
            notTonight: [Self.englishNetflixMovie.id, Self.lateNightMovie.id], // All excluded
            abandoned: profile.abandoned,
            recommendationStyle: profile.recommendationStyle,
            tagWeights: profile.tagWeights
        )

        let movies = [Self.englishNetflixMovie, Self.lateNightMovie]

        // When: Recommending
        let output = engine.recommend(from: movies, profile: profile)

        // Then: Should have stop condition
        XCTAssertNil(output.movie)
        XCTAssertEqual(output.stopCondition, .allOptionsExhausted)
    }

    func testStopConditionWhenNoLanguageMatch() {
        // Given: User language not in movie pool
        let profile = GWUserProfileComplete(
            userId: "french-user",
            preferredLanguages: ["french"],
            platforms: ["netflix", "prime", "jio_hotstar"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 200),
            mood: "neutral",
            intentTags: ["safe_bet"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishNetflixMovie, Self.hindiHotstarMovie]

        // When: Recommending
        let output = engine.recommend(from: movies, profile: profile)

        // Then: Should have noLanguageMatch stop condition
        XCTAssertNil(output.movie)
        XCTAssertEqual(output.stopCondition, .noLanguageMatch)
    }

    func testStopConditionWhenNoPlatformMatch() {
        // Given: User platform not in movie pool
        let profile = GWUserProfileComplete(
            userId: "apple-user",
            preferredLanguages: ["english", "hindi"],
            platforms: ["apple_tv"], // Only Apple TV
            runtimeWindow: GWRuntimeWindow(min: 60, max: 200),
            mood: "neutral",
            intentTags: ["safe_bet"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishNetflixMovie, Self.hindiHotstarMovie] // Netflix and Hotstar only

        // When: Recommending
        let output = engine.recommend(from: movies, profile: profile)

        // Then: Should have noPlatformMatch stop condition
        XCTAssertNil(output.movie)
        XCTAssertEqual(output.stopCondition, .noPlatformMatch)
    }
}

// MARK: - GWMovie Test Initializer Extension

extension GWMovie {
    /// Test-only initializer for creating fixture movies
    init(
        id: String,
        title: String,
        year: Int,
        runtime: Int,
        language: String,
        platforms: [String],
        poster_url: String?,
        overview: String?,
        genres: [String],
        tags: [String],
        goodscore: Double,
        available: Bool,
        contentType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.runtime = runtime
        self.language = language
        self.platforms = platforms
        self.poster_url = poster_url
        self.overview = overview
        self.genres = genres
        self.tags = tags
        self.goodscore = goodscore
        self.voteCount = 1000 // Default passing value for test fixtures
        self.available = available
        self.contentType = contentType
    }
}
