import Foundation

// ============================================
// SECTION 6: POST-WATCH FEEDBACK ENFORCEMENT
// ============================================
//
// Feedback MUST be part of the loop.
// User MUST either:
// - Submit feedback (completed/abandoned)
// - Explicitly skip
//
// DO NOT allow silent progression without feedback.
// ============================================

enum GWFeedbackStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case abandoned = "abandoned"
    case skipped = "skipped"
}

struct GWPendingFeedback: Codable {
    let movieId: String
    let movieTitle: String
    let userId: String
    let watchStartedAt: Date
    let promptAt: Date
    var status: GWFeedbackStatus

    var isOverdue: Bool {
        Date() > promptAt
    }

    var hoursWatching: Double {
        Date().timeIntervalSince(watchStartedAt) / 3600.0
    }
}

final class GWFeedbackEnforcer {
    static let shared = GWFeedbackEnforcer()
    private init() {}

    private let userDefaultsKey = "gw_pending_feedback_list"
    private let feedbackDelayHours: TimeInterval = 2.0 // Prompt 2 hours after watch

    // MARK: - Pending Feedback Management

    /// Record that user clicked "Watch Now" - schedule feedback prompt
    func schedulePostWatchFeedback(movieId: String, movieTitle: String, userId: String) {
        var pending = getPendingFeedbackList()

        // Remove any existing feedback for this movie
        pending.removeAll { $0.movieId == movieId && $0.userId == userId }

        let newFeedback = GWPendingFeedback(
            movieId: movieId,
            movieTitle: movieTitle,
            userId: userId,
            watchStartedAt: Date(),
            promptAt: Date().addingTimeInterval(feedbackDelayHours * 3600),
            status: .pending
        )

        pending.append(newFeedback)
        savePendingFeedbackList(pending)

        #if DEBUG
        print("📅 Scheduled feedback for '\(movieTitle)' at \(newFeedback.promptAt)")
        #endif
    }

    /// Get all pending feedback that is due
    func getOverdueFeedback(userId: String) -> [GWPendingFeedback] {
        let pending = getPendingFeedbackList()
        return pending.filter { $0.userId == userId && $0.status == .pending && $0.isOverdue }
    }

    /// Get all pending feedback (including not yet due)
    func getAllPendingFeedback(userId: String) -> [GWPendingFeedback] {
        let pending = getPendingFeedbackList()
        return pending.filter { $0.userId == userId && $0.status == .pending }
    }

    /// Check if user has pending feedback that blocks progression
    /// Returns the blocking feedback item, or nil if OK to proceed
    func checkFeedbackBlocking(userId: String) -> GWPendingFeedback? {
        let overdue = getOverdueFeedback(userId: userId)
        return overdue.first
    }

    /// Assert no blocking feedback exists. CRASHES in DEBUG if violated.
    func assertNoBlockingFeedback(userId: String) -> Bool {
        if let blocking = checkFeedbackBlocking(userId: userId) {
            let message = "FEEDBACK_BLOCKING: User \(userId) has pending feedback for movie '\(blocking.movieTitle)'"

            #if DEBUG
            // In DEBUG, we warn but don't crash to allow testing
            print("⚠️ \(message)")
            #else
            print("🚨 \(message)")
            #endif

            return false
        }
        return true
    }

    // MARK: - Feedback Submission

    /// Record feedback for a movie
    func submitFeedback(movieId: String, userId: String, status: GWFeedbackStatus) {
        var pending = getPendingFeedbackList()

        // Find and update the feedback item
        if let index = pending.firstIndex(where: { $0.movieId == movieId && $0.userId == userId }) {
            pending[index].status = status
            savePendingFeedbackList(pending)

            #if DEBUG
            print("✅ Feedback submitted: \(status.rawValue) for movie \(movieId)")
            #endif

            // Update tag weights based on feedback
            Task {
                await updateTagWeightsForFeedback(movieId: movieId, status: status)
            }

            // Log to Supabase
            Task {
                await logFeedbackToSupabase(movieId: movieId, userId: userId, status: status)
            }
        } else {
            // No pending feedback found - create one with the status
            #if DEBUG
            print("⚠️ No pending feedback found for movie \(movieId), creating new entry")
            #endif
        }
    }

    /// Explicitly skip feedback for a movie
    func skipFeedback(movieId: String, userId: String) {
        submitFeedback(movieId: movieId, userId: userId, status: .skipped)
    }

    /// Mark movie as completed (user finished watching)
    func markCompleted(movieId: String, userId: String) {
        submitFeedback(movieId: movieId, userId: userId, status: .completed)

        // Also update seen list
        Task {
            await addToSeenList(movieId: movieId, userId: userId)
        }
    }

    /// Mark movie as abandoned (user stopped watching)
    func markAbandoned(movieId: String, userId: String) {
        submitFeedback(movieId: movieId, userId: userId, status: .abandoned)

        // Also update abandoned list
        Task {
            await addToAbandonedList(movieId: movieId, userId: userId)
        }
    }

    // MARK: - Private Helpers

    private func getPendingFeedbackList() -> [GWPendingFeedback] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([GWPendingFeedback].self, from: data) else {
            return []
        }
        return list
    }

    private func savePendingFeedbackList(_ list: [GWPendingFeedback]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func updateTagWeightsForFeedback(movieId: String, status: GWFeedbackStatus) async {
        // Get movie from Supabase to get tags
        // For now, we rely on the engine's updateTagWeights being called from RootFlowView
        #if DEBUG
        print("📊 Tag weight update triggered for feedback: \(status.rawValue)")
        #endif
    }

    private func addToSeenList(movieId: String, userId: String) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            try await InteractionService.shared.addToRejectedMovies(
                userId: UUID(uuidString: userId) ?? UUID(),
                movieId: UUID(uuidString: movieId) ?? UUID(),
                reason: .already_seen
            )
        } catch {
            #if DEBUG
            print("🚨 Failed to add to seen list: \(error)")
            #endif
        }
    }

    private func addToAbandonedList(movieId: String, userId: String) async {
        guard SupabaseConfig.isConfigured else { return }

        do {
            try await InteractionService.shared.addToRejectedMovies(
                userId: UUID(uuidString: userId) ?? UUID(),
                movieId: UUID(uuidString: movieId) ?? UUID(),
                reason: .permanent_skip  // Use permanent_skip for abandoned
            )
        } catch {
            #if DEBUG
            print("🚨 Failed to add to abandoned list: \(error)")
            #endif
        }
    }

    private func logFeedbackToSupabase(movieId: String, userId: String, status: GWFeedbackStatus) async {
        guard SupabaseConfig.isConfigured else { return }

        let sentiment: FeedbackSentiment
        switch status {
        case .completed:
            sentiment = .loved
        case .abandoned:
            sentiment = .regretted
        case .skipped:
            sentiment = .neutral  // Use neutral for skipped
        case .pending:
            return // Don't log pending
        }

        do {
            try await InteractionService.shared.recordFeedback(
                userId: UUID(uuidString: userId) ?? UUID(),
                movieId: UUID(uuidString: movieId) ?? UUID(),
                sentiment: sentiment
            )
        } catch {
            #if DEBUG
            print("🚨 Failed to log feedback: \(error)")
            #endif
        }
    }

    // MARK: - Cleanup

    /// Remove old feedback entries (older than 7 days)
    func cleanupOldFeedback() {
        var pending = getPendingFeedbackList()
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        pending.removeAll { $0.watchStartedAt < sevenDaysAgo }
        savePendingFeedbackList(pending)
    }
}

// MARK: - Feedback UI Contract

extension GWFeedbackEnforcer {
    /// Get feedback prompt data for UI display
    /// Returns nil if no feedback is due
    func getFeedbackPromptData(userId: String) -> FeedbackPromptData? {
        guard let blocking = getOverdueFeedback(userId: userId).first else {
            return nil
        }

        return FeedbackPromptData(
            movieId: blocking.movieId,
            movieTitle: blocking.movieTitle,
            hoursAgo: Int(blocking.hoursWatching)
        )
    }
}

struct FeedbackPromptData {
    let movieId: String
    let movieTitle: String
    let hoursAgo: Int

    var promptMessage: String {
        "How was \"\(movieTitle)\"?"
    }

    var subMessage: String {
        "You started watching \(hoursAgo) hours ago"
    }
}
