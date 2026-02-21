import Foundation

// ============================================
// CLIENT-SIDE MOVIE FILTER
// ============================================
// Shared filter logic used by New, Soon, Rent, and Saved tabs.
// Filters are applied locally on already-fetched results.
// Discover tab uses server-side filtering (ExploreService.searchMovies).
// ============================================

enum ClientMovieFilter {

    private static let languageToISO: [String: String] = [
        "english": "en", "hindi": "hi", "japanese": "ja",
        "tamil": "ta", "telugu": "te", "malayalam": "ml",
        "spanish": "es", "korean": "ko", "kannada": "kn",
        "bengali": "bn", "marathi": "mr", "french": "fr",
        "chinese": "zh", "portuguese": "pt", "punjabi": "pa",
        "gujarati": "gu"
    ]

    /// Apply genre/language/mood/duration/rating/decade filters to a movie list.
    /// Returns filtered list. If all filter sets are empty, returns the original list.
    static func apply(
        to movies: [Movie],
        genres: Set<String>,
        languages: Set<String>,
        moods: Set<String>,
        durations: Set<String>,
        ratings: Set<String>,
        decades: Set<String>
    ) -> [Movie] {
        // Early exit: no filters active
        if genres.isEmpty && languages.isEmpty && moods.isEmpty &&
           durations.isEmpty && ratings.isEmpty && decades.isEmpty {
            return movies
        }

        return movies.filter { movie in
            // Genre: movie must have at least one matching genre
            if !genres.isEmpty {
                let movieGenres = Set(movie.genreNames.map { $0 })
                if movieGenres.isDisjoint(with: genres) { return false }
            }

            // Language: movie's original_language ISO code must match
            if !languages.isEmpty {
                guard let lang = movie.original_language?.lowercased() else { return false }
                let isoCodes = Set(languages.compactMap { languageToISO[$0.lowercased()] })
                if !isoCodes.contains(lang) { return false }
            }

            // Mood: match against emotional_profile tags or genre-based mood inference
            if !moods.isEmpty {
                if !matchesMood(movie: movie, moods: moods) { return false }
            }

            // Duration: runtime range matching
            if !durations.isEmpty {
                let runtime = movie.runtimeMinutes
                if runtime <= 0 { return false }
                var anyMatch = false
                for duration in durations {
                    switch duration {
                    case "Under 90 min":
                        if runtime < 90 { anyMatch = true }
                    case "90\u{2013}150 min", "90-150 min":
                        if runtime >= 90 && runtime <= 150 { anyMatch = true }
                    case "150+ min":
                        if runtime >= 150 { anyMatch = true }
                    case "Epic 180+":
                        if runtime >= 180 { anyMatch = true }
                    default:
                        break
                    }
                }
                if !anyMatch { return false }
            }

            // Rating: GoodScore threshold
            if !ratings.isEmpty {
                guard let score = movie.goodScoreDisplay else { return false }
                let rating10 = Double(score) / 10.0
                var anyMatch = false
                for rating in ratings {
                    switch rating {
                    case "6+":
                        if rating10 >= 6.0 { anyMatch = true }
                    case "7+":
                        if rating10 >= 7.0 { anyMatch = true }
                    case "8+":
                        if rating10 >= 8.0 { anyMatch = true }
                    default:
                        break
                    }
                }
                if !anyMatch { return false }
            }

            // Decade: year range matching
            if !decades.isEmpty {
                guard let year = movie.year else { return false }
                var anyMatch = false
                for decade in decades {
                    switch decade {
                    case "2020s":
                        if year >= 2020 && year <= 2029 { anyMatch = true }
                    case "2010s":
                        if year >= 2010 && year <= 2019 { anyMatch = true }
                    case "2000s":
                        if year >= 2000 && year <= 2009 { anyMatch = true }
                    case "90s":
                        if year >= 1990 && year <= 1999 { anyMatch = true }
                    case "80s":
                        if year >= 1980 && year <= 1989 { anyMatch = true }
                    case "Classic":
                        if year < 1980 { anyMatch = true }
                    default:
                        break
                    }
                }
                if !anyMatch { return false }
            }

            return true
        }
    }

    /// Simple mood matching based on genre keywords
    private static func matchesMood(movie: Movie, moods: Set<String>) -> Bool {
        let genres = Set(movie.genreNames.map { $0.lowercased() })
        for mood in moods {
            switch mood.lowercased() {
            case "feel-good":
                if genres.contains("comedy") || genres.contains("romance") ||
                   genres.contains("family") || genres.contains("animation") { return true }
            case "intense":
                if genres.contains("thriller") || genres.contains("action") ||
                   genres.contains("war") { return true }
            case "dark":
                if genres.contains("horror") || genres.contains("crime") ||
                   genres.contains("thriller") { return true }
            case "light-hearted":
                if genres.contains("comedy") || genres.contains("animation") ||
                   genres.contains("family") { return true }
            case "edge-of-seat":
                if genres.contains("thriller") || genres.contains("mystery") ||
                   genres.contains("action") { return true }
            case "inspirational":
                if genres.contains("drama") || genres.contains("biography") ||
                   genres.contains("history") { return true }
            case "fun":
                if genres.contains("comedy") || genres.contains("adventure") ||
                   genres.contains("action") { return true }
            case "epic":
                if genres.contains("war") || genres.contains("history") ||
                   genres.contains("science fiction") || genres.contains("fantasy") { return true }
            case "wild":
                if genres.contains("action") || genres.contains("adventure") ||
                   genres.contains("crime") { return true }
            case "gripping":
                if genres.contains("thriller") || genres.contains("drama") ||
                   genres.contains("mystery") { return true }
            case "visceral":
                if genres.contains("horror") || genres.contains("action") ||
                   genres.contains("war") { return true }
            case "emotional":
                if genres.contains("drama") || genres.contains("romance") { return true }
            default:
                break
            }
        }
        return false
    }
}
