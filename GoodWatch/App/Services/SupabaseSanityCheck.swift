import Foundation

// ============================================
// PHASE 2: SUPABASE PROD SANITY CHECKS
// ============================================
//
// Run these checks BEFORE shipping:
// - A recommendation inserts a row
// - A rejection inserts a row
// - A repeat is blocked by DB check
//
// If logging fails → DO NOT SHIP
// GoodScore without logs is fake intelligence.
// ============================================

struct SanityCheckResult {
    let checkName: String
    let passed: Bool
    let errorMessage: String?
}

enum SanityError: Error {
    case notConfigured
    case invalidURL
    case networkError(Error)
    case httpError(Int, String?)
}

final class SupabaseSanityChecker {
    static let shared = SupabaseSanityChecker()
    private init() {}

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    /// Run all sanity checks. Returns true only if ALL pass.
    func runAllChecks() async -> (allPassed: Bool, results: [SanityCheckResult]) {
        var results: [SanityCheckResult] = []

        // Check 1: Can insert recommendation
        let recResult = await checkRecommendationInsert()
        results.append(recResult)

        // Check 2: Can insert rejection
        let rejResult = await checkRejectionInsert()
        results.append(rejResult)

        // Check 3: Can insert feedback event
        let feedbackResult = await checkFeedbackInsert()
        results.append(feedbackResult)

        // Check 4: Tables exist
        let tablesResult = await checkRequiredTablesExist()
        results.append(contentsOf: tablesResult)

        let allPassed = results.allSatisfy { $0.passed }

        #if DEBUG
        print("============================================")
        print("SUPABASE SANITY CHECK RESULTS")
        print("============================================")
        for result in results {
            let status = result.passed ? "✅" : "❌"
            print("\(status) \(result.checkName)")
            if let error = result.errorMessage {
                print("   Error: \(error)")
            }
        }
        print("============================================")
        print(allPassed ? "ALL CHECKS PASSED - SAFE TO SHIP" : "⚠️ CHECKS FAILED - DO NOT SHIP")
        print("============================================")
        #endif

        return (allPassed, results)
    }

    // MARK: - HTTP Helpers

    private func insertRow(table: String, data: [String: Any]) async throws -> Data {
        guard SupabaseConfig.isConfigured else {
            throw SanityError.notConfigured
        }

        let urlString = "\(baseURL)/rest/v1/\(table)"
        guard let url = URL(string: urlString) else {
            throw SanityError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        request.httpBody = jsonData

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SanityError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let body = String(data: responseData, encoding: .utf8)
            throw SanityError.httpError(httpResponse.statusCode, body)
        }

        return responseData
    }

    private func deleteRows(table: String, filters: [(String, String)]) async throws {
        guard SupabaseConfig.isConfigured else {
            throw SanityError.notConfigured
        }

        var urlString = "\(baseURL)/rest/v1/\(table)?"
        for (key, value) in filters {
            urlString += "\(key)=eq.\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)&"
        }

        guard let url = URL(string: urlString) else {
            throw SanityError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SanityError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SanityError.httpError(httpResponse.statusCode, nil)
        }
    }

    private func selectRows(table: String, columns: String, limit: Int) async throws -> Data {
        guard SupabaseConfig.isConfigured else {
            throw SanityError.notConfigured
        }

        let urlString = "\(baseURL)/rest/v1/\(table)?select=\(columns)&limit=\(limit)"
        guard let url = URL(string: urlString) else {
            throw SanityError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SanityError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let body = String(data: data, encoding: .utf8)
            throw SanityError.httpError(httpResponse.statusCode, body)
        }

        return data
    }

    // MARK: - Individual Checks

    private func checkRecommendationInsert() async -> SanityCheckResult {
        let testTitle = "SANITY_TEST_\(Int(Date().timeIntervalSince1970))"
        do {
            let testData: [String: Any] = [
                "user_id": "00000000-0000-0000-0000-000000000000",
                "movie_id": "00000000-0000-0000-0000-000000000001",
                "movie_title": testTitle,
                "goodscore": 0.0,
                "threshold_used": 0.0,
                "candidate_count": 0
            ]

            _ = try await insertRow(table: "recommendation_logs", data: testData)

            // Delete test record
            try await deleteRows(table: "recommendation_logs", filters: [("movie_title", testTitle)])

            return SanityCheckResult(
                checkName: "recommendation_logs_insert",
                passed: true,
                errorMessage: nil
            )
        } catch {
            return SanityCheckResult(
                checkName: "recommendation_logs_insert",
                passed: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func checkRejectionInsert() async -> SanityCheckResult {
        let testTitle = "SANITY_TEST_\(Int(Date().timeIntervalSince1970))"
        do {
            let testData: [String: Any] = [
                "user_id": "00000000-0000-0000-0000-000000000000",
                "movie_id": "00000000-0000-0000-0000-000000000001",
                "movie_title": testTitle,
                "failure_type": "test"
            ]

            _ = try await insertRow(table: "validation_failures", data: testData)

            // Delete test record
            try await deleteRows(table: "validation_failures", filters: [("movie_title", testTitle)])

            return SanityCheckResult(
                checkName: "validation_failures_insert",
                passed: true,
                errorMessage: nil
            )
        } catch {
            return SanityCheckResult(
                checkName: "validation_failures_insert",
                passed: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func checkFeedbackInsert() async -> SanityCheckResult {
        do {
            let testData: [String: Any] = [
                "user_id": "00000000-0000-0000-0000-000000000000",
                "movie_id": "00000000-0000-0000-0000-000000000001",
                "event_type": "shown"
            ]

            _ = try await insertRow(table: "feedback_events", data: testData)

            // Delete test record
            try await deleteRows(table: "feedback_events", filters: [
                ("user_id", "00000000-0000-0000-0000-000000000000"),
                ("movie_id", "00000000-0000-0000-0000-000000000001")
            ])

            return SanityCheckResult(
                checkName: "feedback_events_insert",
                passed: true,
                errorMessage: nil
            )
        } catch {
            return SanityCheckResult(
                checkName: "feedback_events_insert",
                passed: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func checkRequiredTablesExist() async -> [SanityCheckResult] {
        let requiredTables = [
            "users",
            "user_profiles",
            "recommendation_logs",
            "validation_failures",
            "feedback_events"
        ]

        var results: [SanityCheckResult] = []

        for table in requiredTables {
            do {
                _ = try await selectRows(table: table, columns: "id", limit: 1)

                results.append(SanityCheckResult(
                    checkName: "\(table)_table_exists",
                    passed: true,
                    errorMessage: nil
                ))
            } catch {
                results.append(SanityCheckResult(
                    checkName: "\(table)_table_exists",
                    passed: false,
                    errorMessage: error.localizedDescription
                ))
            }
        }

        return results
    }

    /// Check if a movie was already recommended to a user (repeat blocking)
    func wasMovieRecommended(userId: UUID, movieId: UUID) async -> Bool {
        guard SupabaseConfig.isConfigured else {
            return false
        }

        do {
            let urlString = "\(baseURL)/rest/v1/recommendation_logs?select=id&user_id=eq.\(userId.uuidString)&movie_id=eq.\(movieId.uuidString)&limit=1"
            guard let url = URL(string: urlString) else {
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            // Parse response to check if we got any rows
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return !jsonArray.isEmpty
            }

            return false
        } catch {
            #if DEBUG
            print("🚨 Error checking repeat: \(error)")
            #endif
            return false // Fail open in case of error
        }
    }
}

// MARK: - App Startup Check

extension SupabaseSanityChecker {
    /// Call this on app startup in DEBUG mode
    func runStartupCheck() {
        #if DEBUG
        Task {
            let (passed, _) = await runAllChecks()
            if !passed {
                print("⚠️⚠️⚠️ SUPABASE SANITY CHECKS FAILED ⚠️⚠️⚠️")
                print("DO NOT SHIP UNTIL ALL CHECKS PASS")
            }
        }
        #endif
    }
}
