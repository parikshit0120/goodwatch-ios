import Foundation

// ============================================
// MOVIE DATA MODEL
// ============================================
// Core data model for movies fetched from Supabase.
// Used throughout the app. GWMovie (in GWSpec.swift) wraps this
// for the recommendation engine via init(from: Movie).
// ============================================

// MARK: - Emotional Profile (from Supabase emotional_profile JSONB column)

struct EmotionalProfile: Codable {
    let complexity: Int?
    let darkness: Int?
    let comfort: Int?
    let energy: Int?
    let mentalStimulation: Int?
    let rewatchability: Int?
    let emotionalIntensity: Int?
    let humour: Int?

    enum CodingKeys: String, CodingKey {
        case complexity
        case darkness
        case comfort
        case energy
        case mentalStimulation = "mental_stimulation"
        case rewatchability
        case emotionalIntensity = "emotional_intensity"
        case humour
    }
}

// MARK: - OTT Provider (from Supabase ott_providers JSONB column)

struct OTTProvider: Codable, Identifiable {
    let id: Int
    let name: String
    let logo_path: String?
    let provider_id: Int?
    let display_priority: Int?

    var displayName: String {
        // Normalize common OTT names for display
        let lowered = name.lowercased()
        if lowered.contains("netflix") { return "Netflix" }
        if lowered.contains("amazon prime") || lowered.contains("prime video") { return "Prime Video" }
        if lowered.contains("hotstar") || lowered.contains("jiohotstar") { return "Jio Hotstar" }
        if lowered.contains("apple tv") { return "Apple TV+" }
        if lowered.contains("sony") || lowered.contains("sonyliv") { return "SonyLIV" }
        if lowered.contains("zee5") { return "ZEE5" }
        return name
    }

    /// Deep link URL for the OTT app
    var deepLinkURL: URL? {
        let lowered = name.lowercased()
        if lowered.contains("netflix") {
            return URL(string: "nflx://")
        }
        if lowered.contains("amazon prime") || lowered.contains("prime video") {
            return URL(string: "aiv://")
        }
        if lowered.contains("hotstar") {
            return URL(string: "hotstar://")
        }
        if lowered.contains("apple tv") {
            return URL(string: "com.apple.tv://")
        }
        return nil
    }

    /// Web fallback URL
    var webURL: URL? {
        let lowered = name.lowercased()
        if lowered.contains("netflix") {
            return URL(string: "https://www.netflix.com")
        }
        if lowered.contains("amazon prime") || lowered.contains("prime video") {
            return URL(string: "https://www.primevideo.com")
        }
        if lowered.contains("hotstar") {
            return URL(string: "https://www.hotstar.com")
        }
        if lowered.contains("apple tv") {
            return URL(string: "https://tv.apple.com")
        }
        if lowered.contains("sony") || lowered.contains("sonyliv") {
            return URL(string: "https://www.sonyliv.com")
        }
        if lowered.contains("zee5") {
            return URL(string: "https://www.zee5.com")
        }
        return nil
    }

    /// Check if this provider matches a given OTTPlatform
    func matches(_ platform: OTTPlatform) -> Bool {
        let lowered = name.lowercased()
        switch platform {
        case .netflix:
            return lowered.contains("netflix")
        case .prime:
            return lowered.contains("amazon") || lowered.contains("prime")
        case .jioHotstar:
            return lowered.contains("hotstar") || lowered.contains("jiohotstar")
        case .appleTV:
            return lowered.contains("apple tv")
        case .sonyLIV:
            return lowered.contains("sony") || lowered.contains("sonyliv")
        case .zee5:
            return lowered.contains("zee5")
        }
    }

    // Convenience initializer for cases without full provider info
    init(id: Int = 0, name: String, logo_path: String? = nil, provider_id: Int? = nil, display_priority: Int? = nil) {
        self.id = id
        self.name = name
        self.logo_path = logo_path
        self.provider_id = provider_id
        self.display_priority = display_priority
    }
}

// MARK: - Movie Model

struct Movie: Identifiable, Codable {
    let id: UUID
    let title: String
    let year: Int?
    let overview: String?
    let poster_path: String?
    let original_language: String?
    let vote_average: Double?
    let vote_count: Int?
    let imdb_rating: Double?
    let imdb_votes: Int?
    let runtime: Int?
    let genres: [[String: Any]]?  // JSONB array from Supabase
    let ott_providers: [OTTProvider]?
    let emotional_profile: EmotionalProfile?
    let content_type: String?  // "movie" or "series" / "tv"
    let available: Bool?

    // Multi-source rating enrichment columns
    let rt_critics_score: Int?       // Rotten Tomatoes critics (0-100)
    let rt_audience_score: Int?      // Rotten Tomatoes audience (0-100)
    let metacritic_score: Int?       // Metacritic score (0-100)
    let composite_score: Double?     // Weighted composite (0-10)
    let rating_confidence: Double?   // 0-1 confidence factor

    // Cast and director
    let director: String?            // Director name
    let cast_list: [String]?         // Top cast members from enrichment

    // MARK: - Computed Properties

    /// Rating (prefers composite_score, then IMDb, then TMDB)
    var rating: Double {
        composite_score ?? imdb_rating ?? vote_average ?? 0.0
    }

    /// Runtime in minutes (default 120 if not set)
    var runtimeMinutes: Int {
        runtime ?? 120
    }

    /// Poster URL (full TMDB URL)
    var posterURL: String? {
        guard let path = poster_path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return path }
        return "https://image.tmdb.org/t/p/w500\(path)"
    }

    /// Year as display string
    var yearString: String {
        guard let y = year else { return "" }
        return String(y)
    }

    /// Genre names extracted from genres JSONB
    var genreNames: [String] {
        guard let genreArray = genres else { return [] }
        return genreArray.compactMap { dict in
            dict["name"] as? String
        }
    }

    /// Director display string (nil if empty)
    var directorDisplay: String? {
        guard let d = director, !d.isEmpty else { return nil }
        return d
    }

    /// Top 3 cast members joined by comma
    var castDisplay: String? {
        guard let c = cast_list, !c.isEmpty else { return nil }
        return c.prefix(3).joined(separator: ", ")
    }

    /// Credits pitch line: "Dir. X . A, B, C"
    var pitchLine: String? {
        let parts = [
            directorDisplay.map { "Dir. \($0)" },
            castDisplay
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Platform names from OTT providers
    var platformNames: [String] {
        ott_providers?.map { $0.name } ?? []
    }

    /// Whether the movie is currently available on any platform
    var isAvailable: Bool {
        if let avail = available { return avail }
        return !(ott_providers ?? []).isEmpty
    }

    // MARK: - Platform Matching

    /// Get providers matching user's selected OTT platforms
    func matchingProviders(for userPlatforms: [OTTPlatform]) -> [OTTProvider] {
        guard let providers = ott_providers else { return [] }
        return providers.filter { provider in
            let providerName = provider.name.lowercased()
            return userPlatforms.contains { platform in
                let variations = platformVariations(for: platform)
                return variations.contains { providerName.contains($0) }
            }
        }
    }

    /// Get providers NOT matching user's platforms (for "Also available on")
    func otherProviders(excludingUserPlatforms userPlatforms: [OTTPlatform]) -> [OTTProvider] {
        guard let providers = ott_providers else { return [] }
        let matching = Set(matchingProviders(for: userPlatforms).map { $0.id })
        return providers.filter { !matching.contains($0.id) }
    }

    private func platformVariations(for platform: OTTPlatform) -> [String] {
        switch platform {
        case .jioHotstar:
            return ["jiohotstar", "hotstar", "disney+ hotstar", "jio hotstar"]
        case .prime:
            return ["amazon prime video", "amazon prime video with ads", "amazon video", "prime video"]
        case .netflix:
            return ["netflix", "netflix kids"]
        case .sonyLIV:
            return ["sony liv", "sonyliv"]
        case .zee5:
            return ["zee5"]
        case .appleTV:
            return ["apple tv", "apple tv+"]
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, year, overview, poster_path, original_language
        case vote_average, vote_count, imdb_rating, imdb_votes
        case runtime, content_type, available
        case ott_providers, emotional_profile
        case rt_critics_score, rt_audience_score, metacritic_score
        case composite_score, rating_confidence
        case director, cast_list
        // genres handled separately due to JSONB
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        poster_path = try container.decodeIfPresent(String.self, forKey: .poster_path)
        original_language = try container.decodeIfPresent(String.self, forKey: .original_language)
        vote_average = try container.decodeIfPresent(Double.self, forKey: .vote_average)
        vote_count = try container.decodeIfPresent(Int.self, forKey: .vote_count)
        imdb_rating = try container.decodeIfPresent(Double.self, forKey: .imdb_rating)
        imdb_votes = try container.decodeIfPresent(Int.self, forKey: .imdb_votes)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        content_type = try container.decodeIfPresent(String.self, forKey: .content_type)
        available = try container.decodeIfPresent(Bool.self, forKey: .available)
        ott_providers = try container.decodeIfPresent([OTTProvider].self, forKey: .ott_providers)
        emotional_profile = try container.decodeIfPresent(EmotionalProfile.self, forKey: .emotional_profile)
        rt_critics_score = try container.decodeIfPresent(Int.self, forKey: .rt_critics_score)
        rt_audience_score = try container.decodeIfPresent(Int.self, forKey: .rt_audience_score)
        metacritic_score = try container.decodeIfPresent(Int.self, forKey: .metacritic_score)
        composite_score = try container.decodeIfPresent(Double.self, forKey: .composite_score)
        rating_confidence = try container.decodeIfPresent(Double.self, forKey: .rating_confidence)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        cast_list = try container.decodeIfPresent([String].self, forKey: .cast_list)
        genres = nil // Handled separately if needed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(poster_path, forKey: .poster_path)
        try container.encodeIfPresent(original_language, forKey: .original_language)
        try container.encodeIfPresent(vote_average, forKey: .vote_average)
        try container.encodeIfPresent(vote_count, forKey: .vote_count)
        try container.encodeIfPresent(imdb_rating, forKey: .imdb_rating)
        try container.encodeIfPresent(imdb_votes, forKey: .imdb_votes)
        try container.encodeIfPresent(runtime, forKey: .runtime)
        try container.encodeIfPresent(content_type, forKey: .content_type)
        try container.encodeIfPresent(available, forKey: .available)
        try container.encodeIfPresent(ott_providers, forKey: .ott_providers)
        try container.encodeIfPresent(emotional_profile, forKey: .emotional_profile)
        try container.encodeIfPresent(rt_critics_score, forKey: .rt_critics_score)
        try container.encodeIfPresent(rt_audience_score, forKey: .rt_audience_score)
        try container.encodeIfPresent(metacritic_score, forKey: .metacritic_score)
        try container.encodeIfPresent(composite_score, forKey: .composite_score)
        try container.encodeIfPresent(rating_confidence, forKey: .rating_confidence)
        try container.encodeIfPresent(director, forKey: .director)
        try container.encodeIfPresent(cast_list, forKey: .cast_list)
    }

    // Direct initializer for programmatic creation
    init(
        id: UUID = UUID(),
        title: String,
        year: Int? = nil,
        overview: String? = nil,
        poster_path: String? = nil,
        original_language: String? = nil,
        vote_average: Double? = nil,
        vote_count: Int? = nil,
        imdb_rating: Double? = nil,
        imdb_votes: Int? = nil,
        runtime: Int? = nil,
        genres: [[String: Any]]? = nil,
        ott_providers: [OTTProvider]? = nil,
        emotional_profile: EmotionalProfile? = nil,
        content_type: String? = nil,
        available: Bool? = nil,
        rt_critics_score: Int? = nil,
        rt_audience_score: Int? = nil,
        metacritic_score: Int? = nil,
        composite_score: Double? = nil,
        rating_confidence: Double? = nil,
        director: String? = nil,
        cast_list: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.overview = overview
        self.poster_path = poster_path
        self.original_language = original_language
        self.vote_average = vote_average
        self.vote_count = vote_count
        self.imdb_rating = imdb_rating
        self.imdb_votes = imdb_votes
        self.runtime = runtime
        self.genres = genres
        self.ott_providers = ott_providers
        self.emotional_profile = emotional_profile
        self.content_type = content_type
        self.available = available
        self.rt_critics_score = rt_critics_score
        self.rt_audience_score = rt_audience_score
        self.metacritic_score = metacritic_score
        self.composite_score = composite_score
        self.rating_confidence = rating_confidence
        self.director = director
        self.cast_list = cast_list
    }
}

// MARK: - Supabase Service (Movie Fetching)

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    /// Fetch movies from Supabase
    func fetchMovies(limit: Int = 1000) async throws -> [Movie] {
        let urlString = "\(baseURL)/rest/v1/movies?select=*&limit=\(limit)&order=composite_score.desc.nullslast,imdb_rating.desc.nullslast"
        guard let url = URL(string: urlString) else { throw SupabaseServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SupabaseServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    /// Fetch movies for availability pre-check with filters
    func fetchMoviesForAvailabilityCheck(
        languages: [String],
        contentType: String?,
        acceptCount: Int,
        limit: Int = 500
    ) async throws -> [Movie] {
        var urlString = "\(baseURL)/rest/v1/movies?select=*&limit=\(limit)"

        // Add content type filter
        if let ct = contentType {
            urlString += "&content_type=eq.\(ct)"
        }

        // Order by composite_score (enriched) first, then imdb_rating
        urlString += "&order=composite_score.desc.nullslast,imdb_rating.desc.nullslast"

        guard let url = URL(string: urlString) else { throw SupabaseServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SupabaseServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }
}

enum SupabaseServiceError: Error {
    case invalidURL
    case fetchFailed
}

// MARK: - Decision Timing (Placeholder)

struct GWDecisionTiming {
    var presentedAt: Date = Date()
    var decisionAt: Date?

    var decisionDurationSeconds: Double? {
        guard let decision = decisionAt else { return nil }
        return decision.timeIntervalSince(presentedAt)
    }

    var isQuickDecision: Bool {
        guard let duration = decisionDurationSeconds else { return false }
        return duration < 3.0
    }

    var isHesitantDecision: Bool {
        guard let duration = decisionDurationSeconds else { return false }
        return duration > 30.0
    }

    mutating func recordDecision() {
        decisionAt = Date()
    }
}

// MARK: - Learning Dimensions (Placeholder)

enum GWLearningDimension: String, Codable {
    case tooLong = "too_long"
    case notInMood = "not_in_mood"
    case notInterested = "not_interested"

    static func from(rejectionReason: String) -> GWLearningDimension? {
        switch rejectionReason.lowercased() {
        case "too long": return .tooLong
        case "not in the mood": return .notInMood
        case "not interested": return .notInterested
        default: return nil
        }
    }
}

struct GWDimensionalLearning: Codable {
    var dimensions: [String: Int] = [:]

    mutating func recordRejection(dimension: GWLearningDimension) {
        dimensions[dimension.rawValue, default: 0] += 1
    }
}

struct GWPlatformBias: Codable {
    var accepts: [String: Int] = [:]
    var rejects: [String: Int] = [:]

    mutating func recordAccept(platform: String) {
        accepts[platform, default: 0] += 1
    }

    mutating func recordReject(platform: String) {
        rejects[platform, default: 0] += 1
    }
}
