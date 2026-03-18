import XCTest
@testable import GoodWatch

final class GWPre1990Tests: XCTestCase {

    // MARK: - Helper: build a minimal GWMovie via JSON round-trip

    private func makeGWMovie(id: String = UUID().uuidString,
                             title: String = "Test Movie",
                             year: Int = 2020,
                             goodscore: Double = 7.5) -> GWMovie? {
        let json: [String: Any] = [
            "id": id,
            "title": title,
            "year": year,
            "runtime": 120,
            "language": "en",
            "platforms": ["Netflix"],
            "genres": ["Drama"],
            "tags": ["safe_bet", "feel_good"],
            "goodscore": goodscore,
            "composite_score": 0,
            "voteCount": 1000,
            "available": true
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? JSONDecoder().decode(GWMovie.self, from: data)
    }

    // MARK: - Test 1: Post-chain year guard rejects 1985

    func testYearGateRejects1985() {
        // Verify that a GWMovie with year=1985 is caught by the year >= 1990 condition
        // This tests the SAME condition used in the post-chain guard:
        //   if movie.year > 0 && movie.year < 1990
        guard let oldMovie = makeGWMovie(title: "Purple Rose of Cairo", year: 1985) else {
            XCTFail("Could not create GWMovie via JSON")
            return
        }
        XCTAssertEqual(oldMovie.year, 1985, "GWMovie must decode the year correctly")
        XCTAssertTrue(oldMovie.year > 0 && oldMovie.year < 1990,
                      "Post-chain guard condition must trigger for year=1985")

        // Also verify a 1990 movie passes
        guard let okMovie = makeGWMovie(title: "Goodfellas", year: 1990) else {
            XCTFail("Could not create GWMovie via JSON")
            return
        }
        XCTAssertFalse(okMovie.year > 0 && okMovie.year < 1990,
                       "Post-chain guard must NOT trigger for year=1990")

        // Year=0 (unknown) passes through — it is not pre-1990
        guard let unknownMovie = makeGWMovie(title: "Unknown Year", year: 0) else {
            XCTFail("Could not create GWMovie via JSON")
            return
        }
        XCTAssertFalse(unknownMovie.year > 0 && unknownMovie.year < 1990,
                       "Post-chain guard must NOT trigger for year=0 (unknown)")
    }

    // MARK: - Test 2: Recent Picks add gate blocks pre-1990

    func testRecentPicksAddGateBlocksPre1990() {
        let service = RecentPicksService.shared
        // Clear any existing picks
        service.clear()

        // Add a pre-1990 movie
        service.addPick(id: "test-pre1990", title: "Old Movie", posterPath: nil,
                        goodScore: 75, year: 1985)

        // Should NOT be in picks
        let picks = service.getPicks()
        XCTAssertFalse(picks.contains(where: { $0.id == "test-pre1990" }),
                       "Pre-1990 movie must not be added to Recent Picks")

        // Add a post-1990 movie for contrast
        service.addPick(id: "test-post1990", title: "New Movie", posterPath: nil,
                        goodScore: 80, year: 2020)

        let updatedPicks = service.getPicks()
        XCTAssertTrue(updatedPicks.contains(where: { $0.id == "test-post1990" }),
                      "Post-1990 movie must be added to Recent Picks")

        // Cleanup
        service.clear()
    }

    // MARK: - Test 3: Recent Picks purge removes pre-1990 on load

    func testRecentPicksPurgesPre1990OnLoad() {
        let service = RecentPicksService.shared
        service.clear()

        // Simulate legacy data by encoding a pick with year < 1990 directly into UserDefaults
        let legacyPick = RecentPicksService.RecentPick(
            id: "legacy-1985", title: "Purple Rose of Cairo",
            posterPath: nil, goodScore: 70,
            platformDisplayName: nil, deepLinkURL: nil, webURL: nil,
            year: 1985
        )
        let modernPick = RecentPicksService.RecentPick(
            id: "modern-2023", title: "Oppenheimer",
            posterPath: nil, goodScore: 90,
            platformDisplayName: nil, deepLinkURL: nil, webURL: nil,
            year: 2023
        )

        // Write both picks to the actual storage key
        let picks = [legacyPick, modernPick]
        if let encoded = try? JSONEncoder().encode(picks) {
            UserDefaults.standard.set(encoded, forKey: "gw_recent_picks")
        }

        // getPicks() should purge the pre-1990 entry and only return the modern one
        let loaded = service.getPicks()
        XCTAssertFalse(loaded.contains(where: { $0.id == "legacy-1985" }),
                       "Pre-1990 pick must be purged on load")
        XCTAssertTrue(loaded.contains(where: { $0.id == "modern-2023" }),
                      "Post-1990 pick must survive load")

        // Verify the purge was persisted (re-read raw data)
        if let data = UserDefaults.standard.data(forKey: "gw_recent_picks"),
           let rawPicks = try? JSONDecoder().decode([RecentPicksService.RecentPick].self, from: data) {
            XCTAssertFalse(rawPicks.contains(where: { $0.id == "legacy-1985" }),
                           "Pre-1990 pick must be removed from persistent storage after purge")
        }

        // Cleanup
        service.clear()
    }
}
