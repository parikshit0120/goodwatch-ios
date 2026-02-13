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
    let type: String?  // "flatrate", "ads", "rent", "buy" — nil for legacy data

    var displayName: String {
        // Normalize common OTT names for display
        // Rental-specific platforms keep their own identity
        let lowered = name.lowercased()
        let isRental = type == "rent" || type == "buy"

        // Rental platforms — keep distinct names
        if lowered == "google play movies" { return "Google Play" }
        if lowered == "youtube" { return "YouTube" }
        if lowered == "amazon video" && isRental { return "Amazon" }

        // Subscription platforms
        if lowered.contains("netflix") { return "Netflix" }
        if lowered.contains("amazon prime") || lowered.contains("prime video") { return "Prime Video" }
        if lowered.contains("amazon video") { return "Prime Video" }  // fallback for non-rental Amazon Video
        if lowered.contains("hotstar") || lowered.contains("jiohotstar") { return "Jio Hotstar" }
        if lowered.contains("apple tv") && isRental { return "Apple TV" }  // rental Apple TV (store), not Apple TV+
        if lowered.contains("apple tv") { return "Apple TV+" }             // subscription Apple TV+
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
        if lowered == "amazon video" {
            return URL(string: "aiv://")
        }
        if lowered.contains("hotstar") {
            return URL(string: "hotstar://")
        }
        if lowered.contains("apple tv") {
            return URL(string: "com.apple.tv://")
        }
        if lowered == "youtube" {
            return URL(string: "youtube://")
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
        if lowered == "amazon video" {
            return URL(string: "https://www.amazon.in")
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
        if lowered == "google play movies" {
            return URL(string: "https://play.google.com/store/movies")
        }
        if lowered == "youtube" {
            return URL(string: "https://www.youtube.com")
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
    init(id: Int = 0, name: String, logo_path: String? = nil, provider_id: Int? = nil, display_priority: Int? = nil, type: String? = nil) {
        self.id = id
        self.name = name
        self.logo_path = logo_path
        self.provider_id = provider_id
        self.display_priority = display_priority
        self.type = type
    }
}

// MARK: - Genre (from Supabase genres JSONB column)

struct Genre: Codable, Identifiable {
    let id: Int
    let name: String
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
    let genres: [Genre]?  // JSONB array from Supabase
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

    /// Runtime in minutes. For movies defaults to 120 if not set.
    /// For series, the DB runtime field is unreliable (often null or total runtime).
    var runtimeMinutes: Int {
        if isSeries {
            // For series: if runtime exists and looks like per-episode (< 120), use it.
            // Otherwise don't assume — return 0 to signal "unknown".
            if let r = runtime, r > 0 && r <= 120 {
                return r
            }
            return 0  // Unknown episode runtime
        }
        return runtime ?? 120
    }

    /// Whether this is a series/TV show
    var isSeries: Bool {
        let ct = content_type?.lowercased() ?? ""
        return ct == "series" || ct == "tv"
    }

    /// Content type display label
    var contentTypeLabel: String {
        isSeries ? "Series" : "Movie"
    }

    /// Display-friendly runtime string that accounts for series (per-episode) vs movie
    var runtimeDisplay: String {
        if isSeries {
            let mins = runtimeMinutes
            if mins > 0 {
                return "\(mins) min/ep"
            }
            return "Series"  // Don't show bogus runtime
        } else {
            let mins = runtimeMinutes
            let hours = mins / 60
            let remainder = mins % 60
            if hours > 0 {
                return "\(hours)h \(remainder)m"
            }
            return "\(mins)m"
        }
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
        return genreArray.map { $0.name }
    }

    /// GoodScore on 0-100 scale, matching Pick For Me display.
    /// Uses composite_score (enriched multi-source), fallback to IMDb+TMDB blend, then raw rating.
    var goodScoreDisplay: Int? {
        if let cs = composite_score, cs > 0 {
            return Int(round(cs * 10))
        } else if let imdb = imdb_rating, let tmdb = vote_average, imdb > 0 && tmdb > 0 {
            return Int(round(((imdb * 0.75) + (tmdb * 0.25)) * 10))
        } else if let rating = imdb_rating ?? vote_average, rating > 0 {
            return Int(round(rating * 10))
        }
        return nil
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

    /// Overview trimmed to the first complete sentence for a succinct summary.
    /// If the first sentence is too long, trims to ~25 words at a natural break.
    var shortOverview: String? {
        guard let text = overview, !text.isEmpty else { return nil }

        // Try to get the first complete sentence (end at period followed by space or end-of-string)
        // Look for sentence-ending punctuation: ". " or "." at end
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dotRange = trimmed.range(of: ". ", options: .literal) {
            let firstSentence = String(trimmed[trimmed.startIndex..<dotRange.lowerBound]) + "."
            let wordCount = firstSentence.split(separator: " ").count
            // If first sentence is reasonable length (5-30 words), use it
            if wordCount >= 5 && wordCount <= 30 {
                return firstSentence
            }
        }

        // Fallback: if first sentence is too short or too long, use up to 25 words
        // and end at the last natural break (comma, dash, period)
        let words = trimmed.split(separator: " ")
        if words.count <= 25 {
            return trimmed
        }
        let chunk = words.prefix(25).joined(separator: " ")
        // Try to cut at last comma or dash for a clean ending
        if let lastComma = chunk.lastIndex(of: ",") {
            let upToComma = String(chunk[chunk.startIndex..<lastComma])
            if upToComma.split(separator: " ").count >= 8 {
                return upToComma + "."
            }
        }
        return chunk + "."
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

    /// The 6 supported subscription OTT platforms
    static let supportedPlatformKeywords: [(OTTPlatform, [String])] = [
        (.netflix, ["netflix"]),
        (.prime, ["amazon prime video", "amazon prime video with ads", "prime video"]),
        (.jioHotstar, ["jiohotstar", "hotstar", "disney+ hotstar", "jio hotstar"]),
        (.appleTV, ["apple tv", "apple tv+"]),
        (.sonyLIV, ["sony liv", "sonyliv"]),
        (.zee5, ["zee5"]),
    ]

    /// Rental platform names recognized in UI
    static let rentalPlatformNames: Set<String> = [
        "google play movies", "youtube", "amazon video"
    ]

    /// Whether a provider name matches any supported platform (subscription or rental)
    static func isSupportedProvider(_ providerName: String) -> Bool {
        let lowered = providerName.lowercased()
        // Check subscription platforms
        if supportedPlatformKeywords.contains(where: { (_, keywords) in
            keywords.contains { lowered.contains($0) }
        }) { return true }
        // Check rental platforms
        if rentalPlatformNames.contains(lowered) { return true }
        return false
    }

    /// All providers filtered to supported platforms (subscription + rental)
    var supportedProviders: [OTTProvider] {
        guard let providers = ott_providers else { return [] }
        return providers.filter { Movie.isSupportedProvider($0.name) }
    }

    /// Providers available for rent or buy (Apple TV, Google Play, YouTube, Amazon Video)
    var rentalProviders: [OTTProvider] {
        guard let providers = ott_providers else { return [] }
        return providers.filter { $0.type == "rent" || $0.type == "buy" }
    }

    /// Get providers matching user's selected OTT platforms (filtered to supported only)
    func matchingProviders(for userPlatforms: [OTTPlatform]) -> [OTTProvider] {
        return supportedProviders.filter { provider in
            let providerName = provider.name.lowercased()
            return userPlatforms.contains { platform in
                let variations = platformVariations(for: platform)
                return variations.contains { providerName.contains($0) }
            }
        }
    }

    /// Best matching provider for primary CTA — prefers subscription-included platforms
    /// Subscription platforms (Netflix, Hotstar, Apple TV+, SonyLIV, ZEE5) are preferred
    /// over transactional/rental platforms (Prime Video "with ads" variants)
    func bestMatchingProvider(for userPlatforms: [OTTPlatform]) -> OTTProvider? {
        let matches = matchingProviders(for: userPlatforms)
        if matches.isEmpty { return nil }

        // Subscription-first: prefer platforms where content is included with subscription
        // Deprioritize providers with "with ads", "rent", "buy" in the name
        let sorted = matches.sorted { a, b in
            let aIsRental = a.name.lowercased().contains("with ads") ||
                            a.name.lowercased().contains("rent") ||
                            a.name.lowercased().contains("buy")
            let bIsRental = b.name.lowercased().contains("with ads") ||
                            b.name.lowercased().contains("rent") ||
                            b.name.lowercased().contains("buy")
            if aIsRental != bIsRental { return !aIsRental }
            return (a.display_priority ?? 999) < (b.display_priority ?? 999)
        }
        return sorted.first
    }

    /// Get OTHER supported providers not matching user's platforms (for "Also available on")
    func otherProviders(excludingUserPlatforms userPlatforms: [OTTPlatform]) -> [OTTProvider] {
        let matching = Set(matchingProviders(for: userPlatforms).map { $0.id })
        return supportedProviders.filter { !matching.contains($0.id) }
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
        case runtime, genres, content_type, available
        case ott_providers, emotional_profile
        case rt_critics_score, rt_audience_score, metacritic_score
        case composite_score, rating_confidence
        case director, cast_list
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
        // ott_providers may be a proper JSONB array OR a JSON string containing an array.
        // Some DB rows store it as text instead of jsonb — handle both gracefully.
        if let directArray = try? container.decodeIfPresent([OTTProvider].self, forKey: .ott_providers) {
            ott_providers = directArray
        } else if let jsonString = try? container.decodeIfPresent(String.self, forKey: .ott_providers),
                  let jsonData = jsonString.data(using: .utf8) {
            // Try decoding the string as [OTTProvider]
            if let parsed = try? JSONDecoder().decode([OTTProvider].self, from: jsonData) {
                ott_providers = parsed
            } else if let rawArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                // Fallback: manually extract from dictionaries (handles provider_id vs id, logo vs logo_path)
                ott_providers = rawArray.compactMap { dict in
                    guard let name = dict["name"] as? String else { return nil }
                    let id = (dict["id"] as? Int) ?? (dict["provider_id"] as? Int) ?? 0
                    let logoPath = (dict["logo_path"] as? String) ?? (dict["logo"] as? String)
                    let type = dict["type"] as? String
                    return OTTProvider(id: id, name: name, logo_path: logoPath, type: type)
                }
            } else {
                ott_providers = nil
            }
        } else {
            ott_providers = nil
        }
        emotional_profile = try container.decodeIfPresent(EmotionalProfile.self, forKey: .emotional_profile)
        rt_critics_score = try container.decodeIfPresent(Int.self, forKey: .rt_critics_score)
        rt_audience_score = try container.decodeIfPresent(Int.self, forKey: .rt_audience_score)
        metacritic_score = try container.decodeIfPresent(Int.self, forKey: .metacritic_score)
        composite_score = try container.decodeIfPresent(Double.self, forKey: .composite_score)
        rating_confidence = try container.decodeIfPresent(Double.self, forKey: .rating_confidence)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        cast_list = try container.decodeIfPresent([String].self, forKey: .cast_list)
        // genres may be a proper JSONB array OR a JSON string — handle both gracefully.
        if let directArray = try? container.decodeIfPresent([Genre].self, forKey: .genres) {
            genres = directArray
        } else if let jsonString = try? container.decodeIfPresent(String.self, forKey: .genres),
                  let jsonData = jsonString.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([Genre].self, from: jsonData) {
            genres = parsed
        } else {
            genres = nil
        }
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
        try container.encodeIfPresent(genres, forKey: .genres)
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
        genres: [Genre]? = nil,
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

        // Add language filter at DB level (convert full names to ISO 639-1 codes)
        // This ensures we fetch movies in the user's preferred languages, not just top-rated globally
        let isoMap: [String: String] = [
            "english": "en", "hindi": "hi", "tamil": "ta", "telugu": "te",
            "malayalam": "ml", "kannada": "kn", "marathi": "mr", "korean": "ko",
            "japanese": "ja", "spanish": "es", "french": "fr"
        ]
        let isoCodes = languages.compactMap { isoMap[$0.lowercased()] }
        if !isoCodes.isEmpty {
            urlString += "&original_language=in.(\(isoCodes.joined(separator: ",")))"
        }

        // Add content type filter
        // For movies: include content_type = 'movie' OR NULL (many movies lack this field)
        // For series: include content_type = 'tv' OR 'series' (DB may use either)
        if let ct = contentType {
            if ct == "movie" {
                urlString += "&or=(content_type.eq.movie,content_type.is.null)"
            } else {
                // Series: match both 'tv' and 'series' since DB may use either value
                urlString += "&or=(content_type.eq.tv,content_type.eq.series)"
            }
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

// MARK: - Learning Dimensions

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

// MARK: - Decision Timing (Threshold-Gated Learning)

/// Records how long a user took to decide on a recommendation.
/// Always collected from first interaction. Only used in scoring after ≥20 samples.
struct GWDecisionTiming: Codable {
    let movieId: String
    let decisionSeconds: TimeInterval
    let wasAccepted: Bool
    let timestamp: TimeInterval  // Unix timestamp
}

/// Aggregated insights from decision timing data.
/// Only available once threshold (≥20 decisions) is met.
struct GWDecisionTimingInsights {
    let totalDecisions: Int
    let avgAcceptTimeSeconds: Double
    let avgRejectTimeSeconds: Double
    let quickAcceptRate: Double  // Fraction of accepts that happened in < 5s
}
