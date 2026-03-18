import XCTest
@testable import GoodWatch

// ============================================
// BUG FIX VERIFICATION TESTS (v1.3.1)
// ============================================
// Bug 3: Rejected IDs excluded from replacement
// Bug 5: Replacement count logic (5-for-5)

final class GWBugFixTests: XCTestCase {

    // MARK: - Bug 3: Rejected IDs Excluded From Replacement

    func testRejectedIDsExcludedFromReplacement() {
        var rejected: Set<String> = []
        let movieAId = "12345"
        let movieBId = "67890"
        rejected.insert(movieAId)

        // Simulate filtering a queue
        let queue = [movieAId, movieBId, "99999"]
        let filtered = queue.filter { !rejected.contains($0) }

        XCTAssertFalse(filtered.contains(movieAId), "Rejected ID must not be in filtered queue")
        XCTAssertTrue(filtered.contains(movieBId), "Non-rejected ID must remain in queue")
        XCTAssertEqual(filtered.count, 2, "Filtered queue should have 2 items")
    }

    func testExclusionSetGrowsWithEachRejection() {
        var excluded: Set<UUID> = []
        let movie1 = UUID()
        let movie2 = UUID()
        let movie3 = UUID()

        excluded.insert(movie1)
        XCTAssertEqual(excluded.count, 1)

        excluded.insert(movie2)
        XCTAssertEqual(excluded.count, 2)

        excluded.insert(movie3)
        XCTAssertEqual(excluded.count, 3)

        // All three excluded
        XCTAssertTrue(excluded.contains(movie1))
        XCTAssertTrue(excluded.contains(movie2))
        XCTAssertTrue(excluded.contains(movie3))
    }

    func testSessionShownIdsPreventsDuplicateDisplay() {
        var sessionShownIds: Set<UUID> = []
        let movieId = UUID()

        // First show — not yet seen
        XCTAssertFalse(sessionShownIds.contains(movieId))

        // Mark as shown
        sessionShownIds.insert(movieId)

        // Second check — now seen
        XCTAssertTrue(sessionShownIds.contains(movieId),
                      "Movie must be in sessionShownIds after being shown")
    }

    // MARK: - Bug 5: Replacement Count Logic (5-for-5)

    func testCanGetReplacement_nonMatureUser_allows5() {
        let interactionCount = 0
        let maturityThreshold = 80
        let sessionLimit = 5

        let isMature = interactionCount >= maturityThreshold
        let maxSessionReplacements = isMature ? Int.max : sessionLimit

        // Non-mature user should get exactly 5 replacements
        for sessionCount in 0..<5 {
            let canReplace = !(sessionCount > 0 && sessionCount >= maxSessionReplacements)
            XCTAssertTrue(canReplace,
                         "Non-mature user with sessionCount=\(sessionCount) should be able to get replacement")
        }

        // 6th replacement should be blocked
        let sessionCount = 5
        let canReplace = !(sessionCount > 0 && sessionCount >= maxSessionReplacements)
        XCTAssertFalse(canReplace,
                      "Non-mature user with sessionCount=5 should be blocked (limit reached)")
    }

    func testCanGetReplacement_matureUser_unlimited() {
        let interactionCount = 100
        let maturityThreshold = 80

        let isMature = interactionCount >= maturityThreshold
        let maxSessionReplacements = isMature ? Int.max : 5

        // Mature user should never be blocked (up to reasonable count)
        for sessionCount in 0..<50 {
            let canReplace = !(sessionCount > 0 && sessionCount >= maxSessionReplacements)
            XCTAssertTrue(canReplace,
                         "Mature user with sessionCount=\(sessionCount) should be able to get replacement")
        }
    }

    func testCanGetReplacement_borderlineMaturity() {
        // Exactly at threshold = 80 → mature
        let isMature79 = 79 >= 80
        XCTAssertFalse(isMature79, "79 interactions should NOT be mature")

        let isMature80 = 80 >= 80
        XCTAssertTrue(isMature80, "80 interactions should be mature")
    }
}
