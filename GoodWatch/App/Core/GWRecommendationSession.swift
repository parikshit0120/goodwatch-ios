import Foundation
import CryptoKit

// ============================================
// SECTION 8: RECOMMENDATION SESSION TRACKING
// ============================================
//
// Every recommendation attempt must:
// - Have a unique session_id
// - Include input_snapshot_hash for replay/debugging
// - Be logged to Supabase
// ============================================

// MARK: - Recommendation Session

struct GWRecommendationSession: Codable {
    let sessionId: String
    let userId: String
    let inputSnapshotHash: String
    let profileSnapshot: GWProfileSnapshot
    let startedAt: Date
    var endedAt: Date?
    var recommendedMovieId: String?
    var outcome: GWSessionOutcome?
    var candidateMovieIds: [String]
    var rejectionReasons: [String: String]  // movieId -> reason

    init(userId: String, profile: GWUserProfileComplete) {
        self.sessionId = UUID().uuidString
        self.userId = userId
        self.inputSnapshotHash = Self.computeHash(for: profile)
        self.profileSnapshot = GWProfileSnapshot(from: profile)
        self.startedAt = Date()
        self.endedAt = nil
        self.recommendedMovieId = nil
        self.outcome = nil
        self.candidateMovieIds = []
        self.rejectionReasons = [:]
    }

    /// Compute deterministic hash of profile for replay verification
    static func computeHash(for profile: GWUserProfileComplete) -> String {
        let components = [
            profile.userId,
            profile.preferredLanguages.sorted().joined(separator: ","),
            profile.platforms.sorted().joined(separator: ","),
            "\(profile.runtimeWindow.min)-\(profile.runtimeWindow.max)",
            profile.mood,
            profile.intentTags.sorted().joined(separator: ","),
            profile.recommendationStyle.rawValue,
            profile.seen.sorted().joined(separator: ","),
            profile.notTonight.sorted().joined(separator: ","),
            profile.abandoned.sorted().joined(separator: ",")
        ]

        let combined = components.joined(separator: "|")
        let data = Data(combined.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    mutating func complete(movieId: String?, outcome: GWSessionOutcome) {
        self.endedAt = Date()
        self.recommendedMovieId = movieId
        self.outcome = outcome
    }

    mutating func setCandidates(_ movieIds: [String]) {
        self.candidateMovieIds = movieIds
    }

    mutating func addRejection(movieId: String, reason: String) {
        self.rejectionReasons[movieId] = reason
    }
}

struct GWProfileSnapshot: Codable {
    let languages: [String]
    let platforms: [String]
    let runtimeMin: Int
    let runtimeMax: Int
    let mood: String
    let intentTags: [String]
    let style: String
    let excludedCount: Int

    init(from profile: GWUserProfileComplete) {
        self.languages = profile.preferredLanguages
        self.platforms = profile.platforms
        self.runtimeMin = profile.runtimeWindow.min
        self.runtimeMax = profile.runtimeWindow.max
        self.mood = profile.mood
        self.intentTags = profile.intentTags
        self.style = profile.recommendationStyle.rawValue
        self.excludedCount = profile.allExcludedIds.count
    }
}

enum GWSessionOutcome: String, Codable {
    case movieRecommended = "movie_recommended"
    case noValidMovie = "no_valid_movie"
    case profileIncomplete = "profile_incomplete"
    case error = "error"
}

// MARK: - Session Manager

final class GWSessionManager {
    static let shared = GWSessionManager()
    private init() {}

    private var currentSession: GWRecommendationSession?

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    /// Start a new recommendation session
    func startSession(userId: String, profile: GWUserProfileComplete) -> GWRecommendationSession {
        let session = GWRecommendationSession(userId: userId, profile: profile)
        currentSession = session

        #if DEBUG
        print("📍 Session started: \(session.sessionId)")
        print("   Hash: \(session.inputSnapshotHash)")
        #endif

        return session
    }

    /// Complete the current session
    func completeSession(movieId: String?, outcome: GWSessionOutcome) {
        guard var session = currentSession else { return }
        session.complete(movieId: movieId, outcome: outcome)

        // Log to Supabase asynchronously
        Task {
            await logSessionToSupabase(session)
        }

        #if DEBUG
        print("📍 Session completed: \(session.sessionId) -> \(outcome.rawValue)")
        #endif

        currentSession = nil
    }

    /// Get current session ID for logging
    var currentSessionId: String? {
        currentSession?.sessionId
    }

    /// Set candidates and rejection reasons for the current session
    func setCandidatesAndRejections(candidates: [String], rejections: [String: String]) {
        currentSession?.setCandidates(candidates)
        for (movieId, reason) in rejections {
            currentSession?.addRejection(movieId: movieId, reason: reason)
        }
    }

    /// Log session to Supabase with full replay data
    private func logSessionToSupabase(_ session: GWRecommendationSession) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            let profileData = try JSONEncoder().encode(session.profileSnapshot)
            let profileString = String(data: profileData, encoding: .utf8) ?? "{}"

            // Serialize candidate IDs and rejection reasons for replay
            let candidatesJSON = try JSONSerialization.data(withJSONObject: session.candidateMovieIds)
            let candidatesString = String(data: candidatesJSON, encoding: .utf8) ?? "[]"

            let rejectionsJSON = try JSONSerialization.data(withJSONObject: session.rejectionReasons)
            let rejectionsString = String(data: rejectionsJSON, encoding: .utf8) ?? "{}"

            let insertData: [String: Any] = [
                "session_id": session.sessionId,
                "user_id": session.userId,
                "input_snapshot_hash": session.inputSnapshotHash,
                "profile_snapshot": profileString,
                "started_at": ISO8601DateFormatter().string(from: session.startedAt),
                "ended_at": session.endedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "recommended_movie_id": session.recommendedMovieId as Any,
                "outcome": session.outcome?.rawValue as Any,
                "candidate_movie_ids": candidatesString,
                "rejection_reasons": rejectionsString
            ]

            let urlString = "\(baseURL)/rest/v1/recommendation_sessions"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let jsonData = try JSONSerialization.data(withJSONObject: insertData)
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                #if DEBUG
                print("🚨 Failed to log session to Supabase")
                #endif
                return
            }

            #if DEBUG
            print("📊 Session logged to Supabase with \(session.candidateMovieIds.count) candidates")
            #endif
        } catch {
            #if DEBUG
            print("🚨 Session logging error: \(error)")
            #endif
        }
    }

    // MARK: - Replay Support

    /// Replay a recommendation from a session ID
    /// Returns the session details for debugging
    func getSessionForReplay(sessionId: String) async -> GWRecommendationSession? {
        guard SupabaseConfig.isConfigured else { return nil }

        do {
            let urlString = "\(baseURL)/rest/v1/recommendation_sessions?session_id=eq.\(sessionId)&limit=1"
            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse response - would need to decode and reconstruct session
            // For now, log the raw data for debugging
            #if DEBUG
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = json.first {
                print("📍 Replay session found: \(first)")
            }
            #endif

            return nil // Full implementation would decode the session
        } catch {
            #if DEBUG
            print("🚨 Replay fetch error: \(error)")
            #endif
            return nil
        }
    }
}

// ============================================
// SECTION 10: PROFILE COMPLETENESS CHECK
// ============================================

struct GWProfileCompletenessResult {
    let isComplete: Bool
    let missingFields: [String]
    let completionPercentage: Double

    var canProceed: Bool {
        // Minimum requirements: language AND platform must be set
        !missingFields.contains("preferredLanguages") && !missingFields.contains("platforms")
    }
}

extension GWUserProfileComplete {
    /// Check if profile has minimum required fields for recommendation
    func checkCompleteness() -> GWProfileCompletenessResult {
        var missingFields: [String] = []
        let totalFields = 5
        var completedFields = 0

        // Required: Languages
        if preferredLanguages.isEmpty {
            missingFields.append("preferredLanguages")
        } else {
            completedFields += 1
        }

        // Required: Platforms
        if platforms.isEmpty {
            missingFields.append("platforms")
        } else {
            completedFields += 1
        }

        // Optional but scored: Mood
        if mood.isEmpty || mood == "neutral" {
            // Not missing, but default
            completedFields += 1
        } else {
            completedFields += 1
        }

        // Optional but scored: Intent tags
        if intentTags.isEmpty {
            missingFields.append("intentTags")
        } else {
            completedFields += 1
        }

        // Optional but scored: Runtime
        if runtimeWindow.min == 60 && runtimeWindow.max == 180 {
            // Default runtime, count as complete
            completedFields += 1
        } else {
            completedFields += 1
        }

        let percentage = Double(completedFields) / Double(totalFields) * 100

        return GWProfileCompletenessResult(
            isComplete: missingFields.isEmpty,
            missingFields: missingFields,
            completionPercentage: percentage
        )
    }
}

// MARK: - Profile Completeness Guard

final class GWProfileGuard {
    static let shared = GWProfileGuard()
    private init() {}

    /// Check if profile is complete enough for recommendations
    /// Returns nil if OK, error message if blocked
    func guardRecommendation(profile: GWUserProfileComplete) -> String? {
        let completeness = profile.checkCompleteness()

        if !completeness.canProceed {
            let missing = completeness.missingFields.joined(separator: ", ")
            let message = "PROFILE_INCOMPLETE: Missing required fields: \(missing)"

            #if DEBUG
            print("🚫 \(message)")
            #endif

            // Log to Supabase
            Task {
                await logProfileIncomplete(userId: profile.userId, missingFields: completeness.missingFields)
            }

            return message
        }

        return nil
    }

    private func logProfileIncomplete(userId: String, missingFields: [String]) async {
        guard SupabaseConfig.isConfigured else { return }

        let insertData: [String: Any] = [
            "user_id": userId,
            "movie_id": "00000000-0000-0000-0000-000000000000",
            "movie_title": "PROFILE_INCOMPLETE",
            "failure_type": "profile_incomplete",
            "failure_details": "{\"missing_fields\": \"\(missingFields.joined(separator: ","))\"}"
        ]

        do {
            let urlString = "\(SupabaseConfig.url)/rest/v1/validation_failures"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let jsonData = try JSONSerialization.data(withJSONObject: insertData)
            request.httpBody = jsonData

            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("🚨 Failed to log profile incomplete: \(error)")
            #endif
        }
    }
}
