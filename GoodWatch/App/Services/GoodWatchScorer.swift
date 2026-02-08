import Foundation

struct GoodWatchScorer {
    static func score(movie: Movie, ctx: UserContext) -> Double {
        var score = 0.0

        // Rating component (max ~5 from rating 10)
        score += movie.rating * 0.5

        // Popularity component (max ~3)
        let votes = Double(movie.imdb_votes ?? movie.vote_count ?? 0)
        score += log(votes + 1) * 0.2

        // Runtime match (max ~0.3)
        let diff = abs(movie.runtimeMinutes - ctx.maxDuration)
        score += max(0, 30 - Double(diff)) * 0.01

        // Mood matching based on genres
        let genres = movie.genreNames
        if ctx.mood == .light && genres.contains("Comedy") { score += 0.3 }
        if ctx.mood == .intense && genres.contains("Thriller") { score += 0.3 }
        if ctx.mood == .intense && genres.contains("Action") { score += 0.2 }
        if ctx.mood == .feelGood && genres.contains("Drama") { score += 0.2 }
        if ctx.mood == .feelGood && genres.contains("Romance") { score += 0.2 }

        // Emotional profile bonus if available
        if let profile = movie.emotional_profile {
            switch ctx.mood {
            case .light:
                if let humour = profile.humour, humour >= 6 { score += 0.2 }
                if let comfort = profile.comfort, comfort >= 6 { score += 0.1 }
            case .intense:
                if let intensity = profile.emotionalIntensity, intensity >= 7 { score += 0.2 }
                if let darkness = profile.darkness, darkness >= 5 { score += 0.1 }
            case .feelGood:
                if let comfort = profile.comfort, comfort >= 7 { score += 0.2 }
            case .neutral:
                break
            }
        }

        // Base score
        score += 0.5
        return score
    }

    // Convert raw score to 0-100 GoodScore for display
    static func goodScore(movie: Movie, ctx: UserContext) -> Int {
        let raw = score(movie: movie, ctx: ctx)
        // Normalize: typical raw scores range 3-8, map to 50-100
        let normalized = min(100, max(0, Int((raw / 10.0) * 100)))
        // Ensure minimum display of 50 for any recommended movie
        return max(50, normalized)
    }
}
