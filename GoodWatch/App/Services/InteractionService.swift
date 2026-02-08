import Foundation

// MARK: - Interaction Service
final class InteractionService {
    static let shared = InteractionService()
    private init() {}

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    // MARK: - Record Interaction
    func recordInteraction(
        userId: UUID,
        movieId: UUID,
        action: InteractionAction,
        rejectionReason: String? = nil,
        context: InteractionContext? = nil
    ) async throws {
        let interaction = GWInteraction(
            userId: userId,
            movieId: movieId,
            action: action,
            rejectionReason: rejectionReason,
            context: context
        )

        let urlString = "\(baseURL)/rest/v1/interactions"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(interaction)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Interaction error: \(body)")
            }
            #endif
            throw InteractionServiceError.recordFailed
        }

        #if DEBUG
        print("✅ Recorded interaction: \(action.rawValue) for movie \(movieId)")
        #endif
    }

    // MARK: - Record Movie Shown
    func recordShown(userId: UUID, movieId: UUID) async throws {
        try await recordInteraction(
            userId: userId,
            movieId: movieId,
            action: .shown,
            context: InteractionContext(
                session_id: UUID().uuidString,
                mood_at_time: UserService.shared.currentProfile?.mood_preferences.current_mood,
                time_of_day: currentTimeOfDay()
            )
        )
    }

    // MARK: - Record Watch Now
    func recordWatchNow(userId: UUID, movieId: UUID) async throws {
        try await recordInteraction(userId: userId, movieId: movieId, action: .watch_now)

        // Schedule feedback prompt (in production, use local notifications)
        scheduleFeedbackPrompt(userId: userId, movieId: movieId, delayHours: 2)
    }

    // MARK: - Record Not Tonight
    func recordNotTonight(userId: UUID, movieId: UUID, reason: String) async throws {
        try await recordInteraction(
            userId: userId,
            movieId: movieId,
            action: .not_tonight,
            rejectionReason: reason
        )
    }

    // MARK: - Record Already Seen
    func recordAlreadySeen(userId: UUID, movieId: UUID) async throws {
        try await recordInteraction(userId: userId, movieId: movieId, action: .already_seen)

        // Also add to permanent rejection list
        try await addToRejectedMovies(userId: userId, movieId: movieId, reason: .already_seen)
    }

    // MARK: - Add to Rejected Movies (Permanent Exclusion)
    func addToRejectedMovies(userId: UUID, movieId: UUID, reason: RejectionType) async throws {
        let rejection = GWRejectedMovie(userId: userId, movieId: movieId, reason: reason)

        let urlString = "\(baseURL)/rest/v1/rejected_movies"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        // Use upsert to handle duplicates
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(rejection)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Rejection error: \(body)")
            }
            #endif
            // Don't throw - rejection might already exist
            return
        }

        #if DEBUG
        print("✅ Added movie \(movieId) to rejected list")
        #endif
    }

    // MARK: - Get Rejected Movie IDs
    func getRejectedMovieIds(userId: UUID) async throws -> Set<UUID> {
        let urlString = "\(baseURL)/rest/v1/rejected_movies?user_id=eq.\(userId.uuidString)&select=movie_id"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct RejectionRow: Codable {
            let movie_id: UUID
        }

        let rows = try JSONDecoder().decode([RejectionRow].self, from: data)
        return Set(rows.map { $0.movie_id })
    }

    // MARK: - Get Recently Rejected Movie IDs (Last 7 days)
    func getRecentlyRejectedMovieIds(userId: UUID) async throws -> Set<UUID> {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let dateString = ISO8601DateFormatter().string(from: sevenDaysAgo)

        let urlString = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId.uuidString)&action=in.(not_tonight,already_seen)&created_at=gte.\(dateString)&select=movie_id"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct InteractionRow: Codable {
            let movie_id: UUID
        }

        let rows = try JSONDecoder().decode([InteractionRow].self, from: data)
        return Set(rows.map { $0.movie_id })
    }

    // MARK: - Get User Interaction Count (Maturity Check)
    /// Returns total count of watch_now interactions for a user
    /// Used to determine if user is "mature" (has sufficient interaction history)
    func getWatchNowCount(userId: UUID) async throws -> Int {
        let urlString = "\(baseURL)/rest/v1/interactions?user_id=eq.\(userId.uuidString)&action=eq.watch_now&select=id"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let (_, response) = try await URLSession.shared.data(for: request)

        // Count is returned in the Content-Range header
        if let httpResponse = response as? HTTPURLResponse,
           let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
           let countString = contentRange.split(separator: "/").last,
           let count = Int(countString) {
            return count
        }

        return 0
    }

    // MARK: - Check if User Has Watched Documentaries
    /// Queries Supabase to check if user has ever picked a documentary (watch_now action on a Documentary genre movie)
    func hasWatchedDocumentary(userId: UUID) async throws -> Bool {
        // Query interactions joined with movies where genre contains 'Documentary'
        // Using Supabase's ability to query with inner joins
        let urlString = "\(baseURL)/rest/v1/rpc/user_has_watched_documentary"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let body = ["p_user_id": userId.uuidString]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        // If RPC doesn't exist, fall back to false (treat as new user)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 404 {
            #if DEBUG
            print("⚠️ user_has_watched_documentary RPC not found, defaulting to false")
            #endif
            return false
        }

        // Response is a boolean
        if let result = try? JSONDecoder().decode(Bool.self, from: data) {
            return result
        }

        return false
    }

    // MARK: - Get User Maturity Info (Combined Check)
    /// Returns user maturity status - whether they're a new user and if they've watched documentaries
    struct UserMaturityInfo {
        let watchNowCount: Int
        let hasWatchedDocumentary: Bool

        /// User is considered "mature" if they have at least 5 watch_now interactions
        var isMatureUser: Bool {
            watchNowCount >= 5
        }

        /// Documentaries should be shown if user is mature OR has explicitly picked documentaries before
        var shouldShowDocumentaries: Bool {
            isMatureUser || hasWatchedDocumentary
        }

        /// Kids/animation content should only appear for mature users
        /// New users should NOT see kids content (prevents "Frog and Toad" for adults)
        var hasWatchedKidsContent: Bool {
            isMatureUser
        }
    }

    func getUserMaturityInfo(userId: UUID) async -> UserMaturityInfo {
        do {
            async let watchCount = getWatchNowCount(userId: userId)
            async let hasDocumentary = hasWatchedDocumentary(userId: userId)

            return UserMaturityInfo(
                watchNowCount: try await watchCount,
                hasWatchedDocumentary: try await hasDocumentary
            )
        } catch {
            #if DEBUG
            print("⚠️ Failed to get user maturity info: \(error)")
            #endif
            // Default to restricting documentaries for safety
            return UserMaturityInfo(watchNowCount: 0, hasWatchedDocumentary: false)
        }
    }

    // MARK: - Record Feedback
    func recordFeedback(userId: UUID, movieId: UUID, sentiment: FeedbackSentiment) async throws {
        let feedback = GWFeedback(userId: userId, movieId: movieId, sentiment: sentiment)

        let urlString = "\(baseURL)/rest/v1/feedback"
        guard let url = URL(string: urlString) else { throw InteractionServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(feedback)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Feedback error: \(body)")
            }
            #endif
            throw InteractionServiceError.recordFailed
        }

        // Update user confidence based on feedback
        try await UserService.shared.updateConfidenceLevel(delta: sentiment.confidenceImpact)

        #if DEBUG
        print("✅ Recorded feedback: \(sentiment.rawValue) for movie \(movieId)")
        #endif
    }

    // MARK: - Helpers
    private func currentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    private func scheduleFeedbackPrompt(userId: UUID, movieId: UUID, delayHours: Int) {
        // In production, schedule a local notification
        // For now, store in UserDefaults
        let key = "pending_feedback_\(movieId.uuidString)"
        let promptTime = Date().addingTimeInterval(TimeInterval(delayHours * 3600))
        UserDefaults.standard.set(promptTime.timeIntervalSince1970, forKey: key)
        UserDefaults.standard.set(userId.uuidString, forKey: "\(key)_user")

        #if DEBUG
        print("📅 Scheduled feedback prompt for \(delayHours) hours")
        #endif
    }
}

// MARK: - Errors
enum InteractionServiceError: Error {
    case invalidURL
    case recordFailed
    case fetchFailed
}

// ============================================
// FUTURE-PROOFING: Learning Signal Extensions
// ============================================
// These extensions prepare for dimensional learning without
// modifying existing interaction recording behavior.
// ============================================

extension InteractionService {
    // MARK: - Dimensional Learning (PLACEHOLDER)

    /// Record rejection with learning dimension for future analysis
    /// NOTE: Currently stores locally only. Future: sync to Supabase.
    func recordRejectionWithLearning(
        userId: UUID,
        movieId: UUID,
        rejectionReason: String,
        platforms: [String]
    ) async throws {
        // Record the basic interaction first
        try await recordNotTonight(userId: userId, movieId: movieId, reason: rejectionReason)

        // PLACEHOLDER: Store dimensional learning data locally
        // Future: This will be persisted to Supabase and used in scoring
        if let dimension = GWLearningDimension.from(rejectionReason: rejectionReason) {
            var learning = loadDimensionalLearning(userId: userId)
            learning.recordRejection(dimension: dimension)
            saveDimensionalLearning(learning, userId: userId)

            #if DEBUG
            print("📊 Learning signal recorded: \(dimension.rawValue) for user \(userId)")
            #endif
        }

        // PLACEHOLDER: Update platform bias
        for platform in platforms {
            var bias = loadPlatformBias(userId: userId)
            bias.recordReject(platform: platform)
            savePlatformBias(bias, userId: userId)
        }
    }

    /// Record acceptance with platform bias tracking
    /// NOTE: Currently stores locally only. Future: sync to Supabase.
    func recordAcceptanceWithBias(
        userId: UUID,
        movieId: UUID,
        platforms: [String]
    ) async throws {
        // Record the basic interaction first
        try await recordWatchNow(userId: userId, movieId: movieId)

        // PLACEHOLDER: Update platform bias
        for platform in platforms {
            var bias = loadPlatformBias(userId: userId)
            bias.recordAccept(platform: platform)
            savePlatformBias(bias, userId: userId)

            #if DEBUG
            print("📊 Platform accept recorded: \(platform) for user \(userId)")
            #endif
        }
    }

    // MARK: - Local Storage Helpers (PLACEHOLDER)

    private func loadDimensionalLearning(userId: UUID) -> GWDimensionalLearning {
        let key = "gw_dimensional_learning_\(userId.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let learning = try? JSONDecoder().decode(GWDimensionalLearning.self, from: data) else {
            return GWDimensionalLearning()
        }
        return learning
    }

    private func saveDimensionalLearning(_ learning: GWDimensionalLearning, userId: UUID) {
        let key = "gw_dimensional_learning_\(userId.uuidString)"
        if let data = try? JSONEncoder().encode(learning) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadPlatformBias(userId: UUID) -> GWPlatformBias {
        let key = "gw_platform_bias_\(userId.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let bias = try? JSONDecoder().decode(GWPlatformBias.self, from: data) else {
            return GWPlatformBias()
        }
        return bias
    }

    private func savePlatformBias(_ bias: GWPlatformBias, userId: UUID) {
        let key = "gw_platform_bias_\(userId.uuidString)"
        if let data = try? JSONEncoder().encode(bias) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Get current learning data for a user (for debugging/analytics)
    func getLearningData(userId: UUID) -> (dimensional: GWDimensionalLearning, platformBias: GWPlatformBias) {
        return (loadDimensionalLearning(userId: userId), loadPlatformBias(userId: userId))
    }
}
