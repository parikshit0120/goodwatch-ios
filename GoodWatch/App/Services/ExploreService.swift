import Foundation

// ============================================
// EXPLORE SERVICE - Supabase API for Explore
// ============================================

final class ExploreService {
    static let shared = ExploreService()
    private init() {}

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    // MARK: - Search Movies (Discover Tab)

    func searchMovies(
        query: String?,
        genres: [String],
        languages: [String],
        moods: [String],
        durations: [String],
        ratings: [String],
        decades: [String],
        sortOption: SortOption,
        limit: Int,
        offset: Int
    ) async throws -> [Movie] {
        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }

        var queryItems = [URLQueryItem(name: "select", value: "*")]

        // Data quality: exclude unreleased, zero-rating, no-poster movies
        appendQualityFilters(to: &queryItems)

        // Search query (title, director, cast)
        if let q = query, !q.isEmpty {
            queryItems.append(URLQueryItem(name: "or", value: "(title.ilike.*\(q)*,director.ilike.*\(q)*,cast_list.cs.{\(q)})"))
        }

        // Genre filter
        if !genres.isEmpty {
            let genreFilter = genres.map { "genres.cs.{\"\($0)\"}" }.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "or", value: "(\(genreFilter))"))
        }

        // Language filter
        if !languages.isEmpty {
            let langCodes = languages.compactMap { languageToISO[$0.lowercased()] }
            if !langCodes.isEmpty {
                queryItems.append(URLQueryItem(name: "original_language", value: "in.(\(langCodes.joined(separator: ",")))"))
            }
        }

        // Duration filter
        if !durations.isEmpty {
            var runtimeConditions: [String] = []
            for duration in durations {
                switch duration {
                case "Under 90 min":
                    runtimeConditions.append("runtime.lt.90")
                case "90–150 min":
                    runtimeConditions.append("and(runtime.gte.90,runtime.lte.150)")
                case "150+ min":
                    runtimeConditions.append("runtime.gte.150")
                case "Epic 180+":
                    runtimeConditions.append("runtime.gte.180")
                default:
                    break
                }
            }
            if !runtimeConditions.isEmpty {
                queryItems.append(URLQueryItem(name: "or", value: "(\(runtimeConditions.joined(separator: ",")))"))
            }
        }

        // Rating filter
        if !ratings.isEmpty {
            var ratingConditions: [String] = []
            for rating in ratings {
                switch rating {
                case "6+":
                    ratingConditions.append("or(composite_score.gte.6,imdb_rating.gte.6,vote_average.gte.6)")
                case "7+":
                    ratingConditions.append("or(composite_score.gte.7,imdb_rating.gte.7,vote_average.gte.7)")
                case "8+":
                    ratingConditions.append("or(composite_score.gte.8,imdb_rating.gte.8,vote_average.gte.8)")
                default:
                    break
                }
            }
            if !ratingConditions.isEmpty {
                queryItems.append(URLQueryItem(name: "or", value: "(\(ratingConditions.joined(separator: ",")))"))
            }
        }

        // Decade filter
        if !decades.isEmpty {
            var yearConditions: [String] = []
            for decade in decades {
                switch decade {
                case "2020s":
                    yearConditions.append("and(year.gte.2020,year.lte.2029)")
                case "2010s":
                    yearConditions.append("and(year.gte.2010,year.lte.2019)")
                case "2000s":
                    yearConditions.append("and(year.gte.2000,year.lte.2009)")
                case "90s":
                    yearConditions.append("and(year.gte.1990,year.lte.1999)")
                case "80s":
                    yearConditions.append("and(year.gte.1980,year.lte.1989)")
                case "Classic":
                    yearConditions.append("year.lt.1980")
                default:
                    break
                }
            }
            if !yearConditions.isEmpty {
                queryItems.append(URLQueryItem(name: "or", value: "(\(yearConditions.joined(separator: ",")))"))
            }
        }

        // Sort
        queryItems.append(URLQueryItem(name: "order", value: sortOptionToQuery(sortOption)))

        // Pagination
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))

        components.queryItems = queryItems
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExploreServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    // MARK: - New Releases

    func fetchNewReleases(
        platform: String?,
        contentType: String?,
        sortOption: SortOption,
        limit: Int
    ) async throws -> [Movie] {
        let orderBy = sortOptionToQuery(sortOption)

        // "New releases" = released in last 90 days
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let cutoff = formatter.string(from: cutoffDate)

        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "release_date", value: "gte.\(cutoff)"),
            URLQueryItem(name: "order", value: orderBy),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        // Data quality: exclude zero-rating, no-poster, unreleased movies
        queryItems.append(URLQueryItem(name: "poster_path", value: "not.is.null"))
        queryItems.append(URLQueryItem(name: "vote_average", value: "gt.0"))
        queryItems.append(URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)"))

        // Platform filter
        if let platform = platform {
            let platformPattern = platformToPattern(platform)
            queryItems.append(URLQueryItem(name: "ott_providers", value: "cs.\(platformPattern)"))
        }

        // Content type filter
        if let contentType = contentType {
            switch contentType {
            case "Movies":
                queryItems.append(URLQueryItem(name: "content_type", value: "eq.movie"))
            case "Series":
                queryItems.append(URLQueryItem(name: "content_type", value: "eq.series"))
            case "Documentary":
                // Documentary is a genre, not a content_type
                queryItems.append(URLQueryItem(name: "genres", value: "cs.[{\"name\":\"Documentary\"}]"))
            default:
                break
            }
        }

        components.queryItems = queryItems
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExploreServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    // MARK: - Movies by Platform

    func fetchMoviesByPlatform(
        platform: String,
        sortOption: SortOption,
        limit: Int
    ) async throws -> [Movie] {
        let platformPattern = platformToPattern(platform)
        let orderBy = sortOptionToQuery(sortOption)

        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "ott_providers", value: "cs.\(platformPattern)"),
            URLQueryItem(name: "order", value: orderBy),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        // Data quality: exclude unreleased, zero-rating, no-poster movies
        appendQualityFilters(to: &queryItems)

        components.queryItems = queryItems
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExploreServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    // MARK: - New Release Counts (last 90 days, per platform)

    func fetchNewReleaseCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let cutoff = formatter.string(from: cutoffDate)

        for platform in ["Netflix", "Prime Video", "Jio Hotstar", "Apple TV+", "ZEE5", "SonyLIV"] {
            do {
                let platformPattern = platformToPattern(platform)
                guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else { continue }
                components.queryItems = [
                    URLQueryItem(name: "select", value: "count"),
                    URLQueryItem(name: "ott_providers", value: "cs.\(platformPattern)"),
                    URLQueryItem(name: "release_date", value: "gte.\(cutoff)"),
                    URLQueryItem(name: "poster_path", value: "not.is.null"),
                    URLQueryItem(name: "vote_average", value: "gt.0"),
                    URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)")
                ]
                guard let url = components.url else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
                request.setValue("exact", forHTTPHeaderField: "Prefer")

                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (200...206).contains(httpResponse.statusCode) {
                    // Parse count from content-range header
                    if let contentRange = httpResponse.value(forHTTPHeaderField: "content-range"),
                       let total = contentRange.split(separator: "/").last,
                       let count = Int(total) {
                        counts[platform] = count
                    }
                }
            } catch {
                counts[platform] = 0
            }
        }

        return counts
    }

    // MARK: - Full Catalog Counts (per platform, with quality filters)

    func fetchPlatformCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let currentYear = Calendar.current.component(.year, from: Date())

        for platform in ["Netflix", "Prime Video", "Jio Hotstar", "Apple TV+", "ZEE5", "SonyLIV"] {
            do {
                let platformPattern = platformToPattern(platform)
                guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else { continue }
                components.queryItems = [
                    URLQueryItem(name: "select", value: "count"),
                    URLQueryItem(name: "ott_providers", value: "cs.\(platformPattern)"),
                    URLQueryItem(name: "poster_path", value: "not.is.null"),
                    URLQueryItem(name: "vote_average", value: "gt.0"),
                    URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)"),
                    URLQueryItem(name: "year", value: "lte.\(currentYear)")
                ]
                guard let url = components.url else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
                request.setValue("exact", forHTTPHeaderField: "Prefer")

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (200...206).contains(httpResponse.statusCode) {
                    if let contentRange = httpResponse.value(forHTTPHeaderField: "content-range"),
                       let total = contentRange.split(separator: "/").last,
                       let count = Int(total) {
                        counts[platform] = count
                    }
                }
            } catch {
                counts[platform] = 0
            }
        }

        return counts
    }

    // MARK: - Rent/Buy Movies

    func fetchRentals(
        platform: String?,
        sortOption: SortOption,
        limit: Int
    ) async throws -> [Movie] {
        let orderBy = sortOptionToQuery(sortOption)

        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: orderBy),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        // Filter by rental platform or all rentals
        if let platform = platform {
            let dbName = dbRentalPlatformName(platform)
            queryItems.append(URLQueryItem(name: "ott_providers", value: "cs.[{\"name\":\"\(dbName)\",\"type\":\"rent\"}]"))
        } else {
            queryItems.append(URLQueryItem(name: "ott_providers", value: "cs.[{\"type\":\"rent\"}]"))
        }

        appendQualityFilters(to: &queryItems)

        components.queryItems = queryItems
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExploreServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    func fetchRentalPlatformCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let currentYear = Calendar.current.component(.year, from: Date())
        let rentalPlatforms = ["Apple TV", "Google Play Movies", "YouTube", "Amazon Video"]

        for platform in rentalPlatforms {
            do {
                let dbName = dbRentalPlatformName(platform)
                guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else { continue }
                components.queryItems = [
                    URLQueryItem(name: "select", value: "count"),
                    URLQueryItem(name: "ott_providers", value: "cs.[{\"name\":\"\(dbName)\",\"type\":\"rent\"}]"),
                    URLQueryItem(name: "poster_path", value: "not.is.null"),
                    URLQueryItem(name: "vote_average", value: "gt.0"),
                    URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)"),
                    URLQueryItem(name: "year", value: "lte.\(currentYear)")
                ]
                guard let url = components.url else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
                request.setValue("exact", forHTTPHeaderField: "Prefer")

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (200...206).contains(httpResponse.statusCode) {
                    if let contentRange = httpResponse.value(forHTTPHeaderField: "content-range"),
                       let total = contentRange.split(separator: "/").last,
                       let count = Int(total) {
                        counts[platform] = count
                    }
                }
            } catch {
                counts[platform] = 0
            }
        }

        return counts
    }

    func fetchTotalRentalCount() async throws -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "count"),
            URLQueryItem(name: "ott_providers", value: "cs.[{\"type\":\"rent\"}]"),
            URLQueryItem(name: "poster_path", value: "not.is.null"),
            URLQueryItem(name: "vote_average", value: "gt.0"),
            URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)"),
            URLQueryItem(name: "year", value: "lte.\(currentYear)")
        ]
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("exact", forHTTPHeaderField: "Prefer")

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           (200...206).contains(httpResponse.statusCode),
           let contentRange = httpResponse.value(forHTTPHeaderField: "content-range"),
           let total = contentRange.split(separator: "/").last,
           let count = Int(total) {
            return count
        }
        return 0
    }

    private func dbRentalPlatformName(_ uiName: String) -> String {
        switch uiName {
        case "Apple TV":            return "Apple TV"
        case "Google Play Movies":  return "Google Play Movies"
        case "YouTube":             return "YouTube"
        case "Amazon Video":        return "Amazon Video"
        default:                    return uiName
        }
    }

    // MARK: - Fetch Movies by IDs (Watchlist)

    func fetchMoviesByIds(_ ids: [String]) async throws -> [Movie] {
        guard !ids.isEmpty else { return [] }

        // Supabase supports `id=in.(uuid1,uuid2,...)`
        let idList = ids.joined(separator: ",")

        guard var components = URLComponents(string: "\(baseURL)/rest/v1/movies") else {
            throw ExploreServiceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "in.(\(idList))"),
            URLQueryItem(name: "order", value: "composite_score.desc.nullslast,vote_average.desc.nullslast"),
            URLQueryItem(name: "limit", value: "\(ids.count)")
        ]
        guard let url = components.url else { throw ExploreServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExploreServiceError.fetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Movie].self, from: data)
    }

    // MARK: - Data Quality Filter

    /// Adds query params to exclude bad data: unreleased, zero-rating, no-poster, canceled movies
    private func appendQualityFilters(to queryItems: inout [URLQueryItem]) {
        // Must have a poster
        queryItems.append(URLQueryItem(name: "poster_path", value: "not.is.null"))
        // Must have a non-zero rating (vote_average > 0)
        queryItems.append(URLQueryItem(name: "vote_average", value: "gt.0"))
        // Exclude unreleased / canceled / planned movies
        // status is either "Released", "Ended", or NULL (older movies without status)
        queryItems.append(URLQueryItem(name: "or", value: "(status.eq.Released,status.eq.Ended,status.is.null)"))
        // Must not be in the future
        let currentYear = Calendar.current.component(.year, from: Date())
        queryItems.append(URLQueryItem(name: "year", value: "lte.\(currentYear)"))
    }

    // MARK: - Helpers

    private func sortOptionToQuery(_ option: SortOption) -> String {
        switch option {
        case .ratingDesc:
            return "composite_score.desc.nullslast,imdb_rating.desc.nullslast,vote_average.desc.nullslast"
        case .ratingAsc:
            return "composite_score.asc.nullslast,imdb_rating.asc.nullslast,vote_average.asc.nullslast"
        case .durationDesc:
            return "runtime.desc.nullslast"
        case .durationAsc:
            return "runtime.asc.nullslast"
        case .yearDesc:
            return "year.desc.nullslast"
        case .yearAsc:
            return "year.asc.nullslast"
        }
    }

    /// Maps UI display names to the actual provider name stored in Supabase ott_providers JSONB
    func dbPlatformName(_ uiName: String) -> String {
        switch uiName {
        case "Netflix":           return "Netflix"
        case "Prime Video":       return "Amazon Prime Video"
        case "Jio Hotstar":       return "JioHotstar"
        case "Apple TV+":         return "Apple TV"
        case "ZEE5":              return "Zee5"
        case "SonyLIV":           return "Sony Liv"
        default:                  return uiName
        }
    }

    private func platformToPattern(_ platform: String) -> String {
        // Map UI name to DB name, then build raw JSON for JSONB containment
        let dbName = dbPlatformName(platform)
        return "[{\"name\":\"\(dbName)\"}]"
    }

    private let languageToISO: [String: String] = [
        "english": "en",
        "hindi": "hi",
        "japanese": "ja",
        "tamil": "ta",
        "telugu": "te",
        "malayalam": "ml",
        "spanish": "es",
        "korean": "ko",
        "kannada": "kn",
        "bengali": "bn",
        "marathi": "mr",
        "french": "fr",
        "chinese": "zh",
        "portuguese": "pt",
        "punjabi": "pa",
        "gujarati": "gu"
    ]
}

enum ExploreServiceError: Error {
    case invalidURL
    case fetchFailed
}
