import XCTest
@testable import GoodWatch

// ============================================
// SECTION 7: END-TO-END INVARIANT TESTS
// ============================================
//
// These tests MUST FAIL HARD if invariants are violated.
// NO silent failures allowed.
//
// Invariants:
// 1. Hindi user → English movie NEVER returned
// 2. Rejected movie NEVER resurfaced
// 3. Profile incomplete → NO recommendation
// 4. Same input → same output (determinism)
// 5. Not-Tonight → next movie shares at least 1 intent tag
// ============================================

final class GWInvariantTests: XCTestCase {

    private let engine = GWRecommendationEngine.shared

    // MARK: - Test Fixtures

    static let englishMovie1 = GWMovie(
        id: "inv-test-en-001",
        title: "English Invariant Test Movie 1",
        year: 2023,
        runtime: 120,
        language: "en",
        platforms: ["netflix", "prime"],
        poster_url: nil,
        overview: "English test movie",
        genres: ["Drama"],
        tags: ["safe_bet", "feel_good", "calm", "medium"],
        goodscore: 85.0,
        available: true
    )

    static let englishMovie2 = GWMovie(
        id: "inv-test-en-002",
        title: "English Invariant Test Movie 2",
        year: 2022,
        runtime: 110,
        language: "english",
        platforms: ["netflix"],
        poster_url: nil,
        overview: "Another English test movie",
        genres: ["Comedy"],
        tags: ["safe_bet", "feel_good", "light", "calm"],
        goodscore: 82.0,
        available: true
    )

    static let hindiMovie1 = GWMovie(
        id: "inv-test-hi-001",
        title: "Hindi Invariant Test Movie",
        year: 2023,
        runtime: 150,
        language: "hi",
        platforms: ["jio_hotstar", "zee5"],
        poster_url: nil,
        overview: "Hindi test movie",
        genres: ["Drama"],
        tags: ["safe_bet", "feel_good", "medium", "calm"],
        goodscore: 80.0,
        available: true
    )

    static let hindiMovie2 = GWMovie(
        id: "inv-test-hi-002",
        title: "Hindi Invariant Test Movie 2",
        year: 2022,
        runtime: 140,
        language: "hindi",
        platforms: ["jio_hotstar"],
        poster_url: nil,
        overview: "Another Hindi test movie",
        genres: ["Comedy"],
        tags: ["safe_bet", "feel_good", "light", "calm"],
        goodscore: 78.0,
        available: true
    )

    // ============================================
    // INVARIANT 1: Hindi user → English movie NEVER returned
    // ============================================

    func testInvariant_HindiUser_NeverGetsEnglishMovie() {
        // Given: Hindi-only user
        let profile = GWUserProfileComplete(
            userId: "invariant-test-hindi-user",
            preferredLanguages: ["hindi"],
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

        // Given: Pool with both English and Hindi movies
        let movies = [Self.englishMovie1, Self.englishMovie2, Self.hindiMovie1, Self.hindiMovie2]

        // When: Request recommendation
        let output = engine.recommend(from: movies, profile: profile)

        // Then: INVARIANT - Must NEVER return English movie
        if let recommended = output.movie {
            let lang = recommended.language.lowercased()
            let isEnglish = lang == "en" || lang == "english"

            XCTAssertFalse(isEnglish,
                "INVARIANT VIOLATION: Hindi user received English movie '\(recommended.title)' with language '\(recommended.language)'")

            // Must be Hindi
            let isHindi = lang == "hi" || lang == "hindi"
            XCTAssertTrue(isHindi,
                "INVARIANT VIOLATION: Hindi user received non-Hindi movie '\(recommended.title)' with language '\(recommended.language)'")
        }

        // Verify no English movies in valid candidates
        for movie in movies {
            let result = engine.isValidMovie(movie, profile: profile)
            let lang = movie.language.lowercased()
            let isEnglish = lang == "en" || lang == "english"

            if isEnglish {
                if case .valid = result {
                    XCTFail("INVARIANT VIOLATION: English movie '\(movie.title)' validated for Hindi user")
                }
            }
        }
    }

    func testInvariant_EnglishUser_NeverGetsHindiMovie() {
        // Given: English-only user
        let profile = GWUserProfileComplete(
            userId: "invariant-test-english-user",
            preferredLanguages: ["english"],
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

        let movies = [Self.englishMovie1, Self.englishMovie2, Self.hindiMovie1, Self.hindiMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        if let recommended = output.movie {
            let lang = recommended.language.lowercased()
            let isHindi = lang == "hi" || lang == "hindi"

            XCTAssertFalse(isHindi,
                "INVARIANT VIOLATION: English user received Hindi movie '\(recommended.title)'")
        }
    }

    // ============================================
    // INVARIANT 2: Rejected movie NEVER resurfaced
    // ============================================

    func testInvariant_RejectedMovie_NeverResurfaces_Seen() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-seen-user",
            preferredLanguages: ["english"],
            platforms: ["netflix", "prime"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [Self.englishMovie1.id], // SEEN this movie
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        // INVARIANT: Must NOT return the seen movie
        if let recommended = output.movie {
            XCTAssertNotEqual(recommended.id, Self.englishMovie1.id,
                "INVARIANT VIOLATION: Seen movie '\(Self.englishMovie1.title)' was resurfaced")
        }

        // Verify isValidMovie rejects it
        let result = engine.isValidMovie(Self.englishMovie1, profile: profile)
        if case .valid = result {
            XCTFail("INVARIANT VIOLATION: Seen movie validated as valid")
        }
    }

    func testInvariant_RejectedMovie_NeverResurfaces_NotTonight() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-nottonight-user",
            preferredLanguages: ["english"],
            platforms: ["netflix", "prime"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [Self.englishMovie1.id], // REJECTED this movie
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        if let recommended = output.movie {
            XCTAssertNotEqual(recommended.id, Self.englishMovie1.id,
                "INVARIANT VIOLATION: NotTonight movie '\(Self.englishMovie1.title)' was resurfaced")
        }
    }

    func testInvariant_RejectedMovie_NeverResurfaces_Abandoned() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-abandoned-user",
            preferredLanguages: ["english"],
            platforms: ["netflix", "prime"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [Self.englishMovie1.id], // ABANDONED this movie
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        if let recommended = output.movie {
            XCTAssertNotEqual(recommended.id, Self.englishMovie1.id,
                "INVARIANT VIOLATION: Abandoned movie '\(Self.englishMovie1.title)' was resurfaced")
        }
    }

    // ============================================
    // INVARIANT 3: Profile incomplete → NO recommendation
    // ============================================

    func testInvariant_IncompleteProfile_EmptyLanguages_NoRecommendation() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-incomplete",
            preferredLanguages: [], // EMPTY - incomplete
            platforms: ["netflix"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        // INVARIANT: Must NOT return a recommendation
        XCTAssertNil(output.movie,
            "INVARIANT VIOLATION: Recommendation returned for incomplete profile (empty languages)")
        XCTAssertNotNil(output.stopCondition,
            "INVARIANT VIOLATION: Stop condition not set for incomplete profile")
    }

    func testInvariant_IncompleteProfile_EmptyPlatforms_NoRecommendation() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-incomplete-platforms",
            preferredLanguages: ["english"],
            platforms: [], // EMPTY - incomplete
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        XCTAssertNil(output.movie,
            "INVARIANT VIOLATION: Recommendation returned for incomplete profile (empty platforms)")
        XCTAssertNotNil(output.stopCondition,
            "INVARIANT VIOLATION: Stop condition not set for incomplete profile")
    }

    func testInvariant_IncompleteProfile_EmptyIntentTags_NoRecommendation() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-incomplete-tags",
            preferredLanguages: ["english"],
            platforms: ["netflix"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: [], // EMPTY - incomplete
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]

        let output = engine.recommend(from: movies, profile: profile)

        XCTAssertNil(output.movie,
            "INVARIANT VIOLATION: Recommendation returned for incomplete profile (empty intent tags)")
        XCTAssertNotNil(output.stopCondition,
            "INVARIANT VIOLATION: Stop condition not set for incomplete profile")
    }

    // ============================================
    // INVARIANT 4: Same input → same output (determinism)
    // ============================================

    func testInvariant_Determinism_SameInput_SameOutput() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-determinism",
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

        let movies = [Self.englishMovie1, Self.englishMovie2]

        // Run recommendation 10 times
        var results: [String?] = []
        for _ in 0..<10 {
            let output = engine.recommend(from: movies, profile: profile)
            results.append(output.movie?.id)
        }

        // INVARIANT: All results must be identical
        let firstResult = results[0]
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result, firstResult,
                "INVARIANT VIOLATION: Non-deterministic output at run \(index): expected '\(firstResult ?? "nil")' got '\(result ?? "nil")'")
        }
    }

    func testInvariant_Determinism_OrderIndependence() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-order",
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

        let movies1 = [Self.englishMovie1, Self.englishMovie2]
        let movies2 = [Self.englishMovie2, Self.englishMovie1] // Reversed order

        let output1 = engine.recommend(from: movies1, profile: profile)
        let output2 = engine.recommend(from: movies2, profile: profile)

        // INVARIANT: Same movies in different order should produce same result
        XCTAssertEqual(output1.movie?.id, output2.movie?.id,
            "INVARIANT VIOLATION: Different order produced different results")
    }

    // ============================================
    // INVARIANT 5: Not-Tonight → next movie shares at least 1 intent tag
    // ============================================

    func testInvariant_NotTonight_NextMovieSharesTag() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-nottonight-tags",
            preferredLanguages: ["english"],
            platforms: ["netflix", "prime"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [Self.englishMovie1.id], // Rejected movie 1
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let movies = [Self.englishMovie1, Self.englishMovie2]
        let rejectedMovie = Self.englishMovie1

        let output = engine.recommendAfterNotTonight(
            from: movies,
            profile: profile,
            rejectedMovie: rejectedMovie
        )

        if let recommended = output.movie {
            // INVARIANT: Next movie must share at least 1 tag with intent tags
            let movieTags = Set(recommended.tags)
            let intentTags = Set(profile.intentTags)
            let intersection = movieTags.intersection(intentTags)

            XCTAssertFalse(intersection.isEmpty,
                "INVARIANT VIOLATION: Next movie '\(recommended.title)' shares no tags with intent \(profile.intentTags)")
        }
    }

    // ============================================
    // INVARIANT 6: GoodScore below threshold → movie NEVER returned
    // ============================================

    func testInvariant_LowGoodScore_NeverReturned() {
        let lowScoreMovie = GWMovie(
            id: "inv-test-low-score",
            title: "Low Score Movie",
            year: 2023,
            runtime: 120,
            language: "en",
            platforms: ["netflix"],
            poster_url: nil,
            overview: "Low score",
            genres: ["Drama"],
            tags: ["safe_bet", "feel_good"],
            goodscore: 50.0, // Below any threshold
            available: true
        )

        let profile = GWUserProfileComplete(
            userId: "invariant-test-low-score",
            preferredLanguages: ["english"],
            platforms: ["netflix"],
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        let result = engine.isValidMovie(lowScoreMovie, profile: profile)

        // INVARIANT: Low score movie must be invalid
        if case .valid = result {
            XCTFail("INVARIANT VIOLATION: Low GoodScore movie (50) was validated")
        }
    }

    // ============================================
    // INVARIANT 7: Platform mismatch → movie NEVER returned
    // ============================================

    func testInvariant_PlatformMismatch_NeverReturned() {
        let profile = GWUserProfileComplete(
            userId: "invariant-test-platform",
            preferredLanguages: ["english"],
            platforms: ["apple_tv"], // Only Apple TV
            runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
            mood: "neutral",
            intentTags: ["safe_bet", "feel_good"],
            seen: [],
            notTonight: [],
            abandoned: [],
            recommendationStyle: .safe,
            tagWeights: [:]
        )

        // Movie only on Netflix
        let movies = [Self.englishMovie1] // Netflix only

        let output = engine.recommend(from: movies, profile: profile)

        // INVARIANT: Must NOT return movie on wrong platform
        XCTAssertNil(output.movie,
            "INVARIANT VIOLATION: Movie on wrong platform was returned")
    }
}
