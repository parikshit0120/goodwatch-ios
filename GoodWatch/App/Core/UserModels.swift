import Foundation

// MARK: - Auth Provider
enum AuthProvider: String, Codable {
    case google
    case apple
    case anonymous
}

// MARK: - GoodWatch User
struct GWUser: Codable, Identifiable {
    let id: UUID
    let auth_provider: String
    let email: String?
    let device_id: String?
    let created_at: String?
    let last_active_at: String?

    static func anonymous(deviceId: String) -> GWUser {
        GWUser(
            id: UUID(),
            auth_provider: AuthProvider.anonymous.rawValue,
            email: nil,
            device_id: deviceId,
            created_at: ISO8601DateFormatter().string(from: Date()),
            last_active_at: nil
        )
    }
}

// MARK: - User Profile
struct GWUserProfile: Codable {
    var id: UUID?
    var user_id: UUID
    var preferred_languages: [String]
    var platforms: [String]
    var mood_preferences: MoodPreferences
    var runtime_preferences: RuntimePreferences
    var confidence_level: Double
    var profile_version: Int
    var updated_at: String?

    static func empty(userId: UUID) -> GWUserProfile {
        GWUserProfile(
            id: nil,
            user_id: userId,
            preferred_languages: [],
            platforms: [],
            mood_preferences: MoodPreferences(),
            runtime_preferences: RuntimePreferences(),
            confidence_level: 0.0,
            profile_version: 1,
            updated_at: nil
        )
    }
}

// MARK: - Mood Preferences
struct MoodPreferences: Codable {
    var current_mood: String?
    var preferred_moods: [String]
    var mood_history: [MoodEntry]

    init(current_mood: String? = nil, preferred_moods: [String] = [], mood_history: [MoodEntry] = []) {
        self.current_mood = current_mood
        self.preferred_moods = preferred_moods
        self.mood_history = mood_history
    }
}

struct MoodEntry: Codable {
    let mood: String
    let timestamp: String
}

// MARK: - Runtime Preferences
struct RuntimePreferences: Codable {
    var max_runtime: Int
    var preferred_range: RuntimeRange

    init(max_runtime: Int = 180, preferred_range: RuntimeRange = .any) {
        self.max_runtime = max_runtime
        self.preferred_range = preferred_range
    }
}

enum RuntimeRange: String, Codable {
    case short = "short"      // < 90 mins
    case medium = "medium"    // 90-120 mins
    case long = "long"        // 120-150 mins
    case any = "any"          // any length

    var maxMinutes: Int {
        switch self {
        case .short: return 90
        case .medium: return 120
        case .long: return 150
        case .any: return 300
        }
    }
}

// MARK: - Interaction
struct GWInteraction: Codable {
    var id: UUID?
    let user_id: UUID
    let movie_id: UUID
    let action: InteractionAction
    let rejection_reason: String?
    let context: InteractionContext?
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, movie_id, action, rejection_reason, context, created_at
    }

    init(userId: UUID, movieId: UUID, action: InteractionAction, rejectionReason: String? = nil, context: InteractionContext? = nil) {
        self.id = nil
        self.user_id = userId
        self.movie_id = movieId
        self.action = action
        self.rejection_reason = rejectionReason
        self.context = context
        self.created_at = ISO8601DateFormatter().string(from: Date())
    }
}

enum InteractionAction: String, Codable {
    case shown
    case watch_now
    case not_tonight
    case already_seen
}

struct InteractionContext: Codable {
    var session_id: String?
    var mood_at_time: String?
    var time_of_day: String?
}

// MARK: - Feedback
struct GWFeedback: Codable {
    var id: UUID?
    let user_id: UUID
    let movie_id: UUID
    let sentiment: FeedbackSentiment
    let created_at: String?

    init(userId: UUID, movieId: UUID, sentiment: FeedbackSentiment) {
        self.id = nil
        self.user_id = userId
        self.movie_id = movieId
        self.sentiment = sentiment
        self.created_at = ISO8601DateFormatter().string(from: Date())
    }
}

enum FeedbackSentiment: String, Codable {
    case loved
    case liked
    case neutral
    case regretted

    var confidenceImpact: Double {
        switch self {
        case .loved: return 0.1
        case .liked: return 0.05
        case .neutral: return 0.0
        case .regretted: return -0.1
        }
    }
}

// MARK: - Rejected Movie
struct GWRejectedMovie: Codable {
    var id: UUID?
    let user_id: UUID
    let movie_id: UUID
    let reason: RejectionType
    let created_at: String?

    init(userId: UUID, movieId: UUID, reason: RejectionType) {
        self.id = nil
        self.user_id = userId
        self.movie_id = movieId
        self.reason = reason
        self.created_at = ISO8601DateFormatter().string(from: Date())
    }
}

enum RejectionType: String, Codable {
    case already_seen
    case not_interested
    case permanent_skip
}
