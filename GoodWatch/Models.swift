import Foundation

// MARK: - Movie
struct Movie: Identifiable, Codable {
    let id: Int
    let title: String
    let year: String
    let rating: Double
    let runtime: String
    let posterURL: String
    var backdropURL: String?
    var overview: String?
    var genres: [String]
    var aiInsight: String?
    var streamingPlatforms: [String]
    var cast: [CastMember]
    
    static let sample = Movie(
        id: 1,
        title: "Dune: Part Two",
        year: "2024",
        rating: 8.8,
        runtime: "2h 46m",
        posterURL: "https://image.tmdb.org/t/p/w500/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg",
        backdropURL: "https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg",
        overview: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.",
        genres: ["Sci-Fi", "Action", "Adventure", "Drama"],
        aiInsight: "An epic tale of destiny and power, this sequel delivers stunning visuals and a deep narrative, perfect for fans of grand-scale storytelling.",
        streamingPlatforms: ["Netflix", "Prime Video", "Max"],
        cast: CastMember.samples
    )
    
    static let samples: [Movie] = [
        Movie(id: 1, title: "Dune: Part Two", year: "2024", rating: 8.8, runtime: "2h 46m",
              posterURL: "https://image.tmdb.org/t/p/w500/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg",
              genres: ["Sci-Fi", "Action"], aiInsight: "Epic sci-fi masterpiece", streamingPlatforms: ["Netflix"], cast: []),
        Movie(id: 2, title: "Interstellar", year: "2014", rating: 8.7, runtime: "2h 49m",
              posterURL: "https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
              genres: ["Sci-Fi", "Drama"], aiInsight: "Mind-bending journey through space and time", streamingPlatforms: ["Prime Video"], cast: []),
        Movie(id: 3, title: "The Godfather", year: "1972", rating: 9.2, runtime: "2h 55m",
              posterURL: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
              genres: ["Crime", "Drama"], aiInsight: "The definitive crime saga", streamingPlatforms: ["Max"], cast: []),
        Movie(id: 4, title: "Oppenheimer", year: "2023", rating: 8.9, runtime: "3h",
              posterURL: "https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
              genres: ["Drama", "History"], aiInsight: "Gripping historical drama", streamingPlatforms: ["Prime Video"], cast: []),
        Movie(id: 5, title: "Past Lives", year: "2023", rating: 8.0, runtime: "1h 46m",
              posterURL: "https://image.tmdb.org/t/p/w500/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg",
              genres: ["Drama", "Romance"], aiInsight: "Beautiful meditation on fate and love", streamingPlatforms: ["Netflix"], cast: []),
        Movie(id: 6, title: "Poor Things", year: "2024", rating: 8.4, runtime: "2h 21m",
              posterURL: "https://image.tmdb.org/t/p/w500/kCGlIMHnOm8JPXq3rXM6c5wMxcT.jpg",
              genres: ["Comedy", "Drama"], aiInsight: "Wildly imaginative and bold", streamingPlatforms: ["Hulu"], cast: []),
        Movie(id: 7, title: "Killers of the Flower Moon", year: "2023", rating: 7.9, runtime: "3h 26m",
              posterURL: "https://image.tmdb.org/t/p/w500/dB6Krk806zeqd0YNp2ngQ9zXteH.jpg",
              genres: ["Crime", "Drama"], aiInsight: "Scorsese's powerful true crime epic", streamingPlatforms: ["Apple TV+"], cast: []),
        Movie(id: 8, title: "Barbie", year: "2023", rating: 7.3, runtime: "1h 54m",
              posterURL: "https://image.tmdb.org/t/p/w500/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg",
              genres: ["Comedy", "Fantasy"], aiInsight: "Fun, colorful, and surprisingly deep", streamingPlatforms: ["Max"], cast: [])
    ]
}

// MARK: - Cast Member
struct CastMember: Identifiable, Codable {
    let id: Int
    let name: String
    let character: String
    let photoURL: String
    
    static let samples: [CastMember] = [
        CastMember(id: 1, name: "Timothée Chalamet", character: "Paul Atreides", photoURL: "https://image.tmdb.org/t/p/w185/BE2sdjpgsa2rNTFa66f7upkaOP.jpg"),
        CastMember(id: 2, name: "Zendaya", character: "Chani", photoURL: "https://image.tmdb.org/t/p/w185/tylFh6ykWXHZnwrnNNUdC4Ld6D5.jpg"),
        CastMember(id: 3, name: "Rebecca Ferguson", character: "Lady Jessica", photoURL: "https://image.tmdb.org/t/p/w185/lJloTOheuQSirSLXNA3JHsrMNfH.jpg"),
        CastMember(id: 4, name: "Florence Pugh", character: "Princess Irulan", photoURL: "https://image.tmdb.org/t/p/w185/fhEsn35uAwUZy16LqJPMrStLdQP.jpg")
    ]
}

// MARK: - Mood
struct Mood: Identifiable {
    let id = UUID()
    let name: String
    var isSelected: Bool = false
    
    static let all: [Mood] = [
        Mood(name: "Chill"), Mood(name: "Intense"), Mood(name: "Feel-Good"),
        Mood(name: "Dark"), Mood(name: "Romantic"), Mood(name: "Mind-Bending"),
        Mood(name: "Laugh"), Mood(name: "Cry"), Mood(name: "Thrill"),
        Mood(name: "Think"), Mood(name: "Adventure"), Mood(name: "Inspire")
    ]
}

// MARK: - Story
struct Story: Identifiable {
    let id = UUID()
    let title: String
    let imageURL: String
    let isNew: Bool
    let movie: Movie?
    
    static let samples: [Story] = [
        Story(title: "Top Picks", imageURL: "https://image.tmdb.org/t/p/w185/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg", isNew: true, movie: Movie.sample),
        Story(title: "Weekend Vibes", imageURL: "https://image.tmdb.org/t/p/w185/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", isNew: true, movie: nil),
        Story(title: "Hidden Gems", imageURL: "https://image.tmdb.org/t/p/w185/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg", isNew: false, movie: nil),
        Story(title: "New Releases", imageURL: "https://image.tmdb.org/t/p/w185/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg", isNew: true, movie: nil)
    ]
}

// MARK: - Curated List
struct CuratedList: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String
    let movieCount: Int
    let updatedAt: String
    var isFeatured: Bool = false
    var tag: String?
    
    static let samples: [CuratedList] = [
        CuratedList(title: "Best 10 Horror on Netflix", subtitle: "GoodWatch Picks", imageURL: "https://image.tmdb.org/t/p/w500/9E2y5Q7WlCVNEhP5GiVTjhEhx1o.jpg", movieCount: 10, updatedAt: "today", isFeatured: true, tag: "GoodWatch Picks"),
        CuratedList(title: "Modern Day Romances", subtitle: "8 films", imageURL: "https://image.tmdb.org/t/p/w500/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg", movieCount: 8, updatedAt: "today"),
        CuratedList(title: "Critically Acclaimed Thrillers", subtitle: "12 films", imageURL: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg", movieCount: 12, updatedAt: "yesterday"),
        CuratedList(title: "Timeless Family Adventures", subtitle: "10 films", imageURL: "https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", movieCount: 10, updatedAt: "week ago")
    ]
}

// MARK: - Mood Category (for Lists Hub)
struct MoodCategory: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String
    
    static let samples: [MoodCategory] = [
        MoodCategory(title: "Feel-Good Vibes", subtitle: "Uplifting stories to brighten your day.", imageURL: "https://image.tmdb.org/t/p/w500/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg"),
        MoodCategory(title: "Intense Thrills", subtitle: "Edge-of-your-seat suspense and excitement.", imageURL: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg"),
        MoodCategory(title: "Deep Thinking", subtitle: "Thought-provoking and philosophical.", imageURL: "https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg"),
        MoodCategory(title: "Romantic Escapes", subtitle: "Love stories to whisk you away.", imageURL: "https://image.tmdb.org/t/p/w500/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg")
    ]
}

// MARK: - User Stats
struct UserStats: Codable {
    var moviesDiscovered: Int = 0
    var pickRate: Int = 0
    var listsCreated: Int = 0
    var totalSwipes: Int = 0
    var dayStreak: Int = 0
    var bestStreak: Int = 0
    var watchedThisMonth: Int = 0
    var totalWatchTime: String = "0h"
    
    var calculatedPickRate: Int {
        guard totalSwipes > 0 else { return 0 }
        return Int((Double(moviesDiscovered) / Double(totalSwipes)) * 100)
    }
}

// MARK: - Watchlist Item
struct WatchlistItem: Identifiable, Codable {
    var id: UUID = UUID()
    let movie: Movie
    var isWatched: Bool = false
    var addedAt: Date = Date()
    var watchedAt: Date? = nil
}

// MARK: - Recent Search
struct RecentSearch: Identifiable {
    let id = UUID()
    let query: String
    let icon: String = "clock"
    
    static let samples: [RecentSearch] = [
        RecentSearch(query: "Sci-Fi Thriller"),
        RecentSearch(query: "Action Movies"),
        RecentSearch(query: "Netflix Series"),
        RecentSearch(query: "Christopher Nolan")
    ]
}

// MARK: - Streaming Platform
struct StreamingPlatform: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    
    static let all: [StreamingPlatform] = [
        StreamingPlatform(name: "Netflix", icon: "play.tv"),
        StreamingPlatform(name: "Prime Video", icon: "play.tv"),
        StreamingPlatform(name: "Hotstar", icon: "play.tv"),
        StreamingPlatform(name: "Max", icon: "play.tv"),
        StreamingPlatform(name: "Apple TV+", icon: "play.tv"),
        StreamingPlatform(name: "Hulu", icon: "play.tv")
    ]
}

// MARK: - User Activity
struct UserActivity: Identifiable {
    let id = UUID()
    let movie: Movie
    let action: String
    let timeAgo: String
    
    static let samples: [UserActivity] = [
        UserActivity(movie: Movie.samples[0], action: "Watched", timeAgo: "2 days ago"),
        UserActivity(movie: Movie.samples[3], action: "Rated 5 stars", timeAgo: "last week"),
        UserActivity(movie: Movie.samples[4], action: "Added to Watchlist", timeAgo: "Oct 1")
    ]
}

// MARK: - Taste Profile
struct TasteProfile {
    let genre: String
    let percentage: Int
    
    static let samples: [TasteProfile] = [
        TasteProfile(genre: "Thriller", percentage: 85),
        TasteProfile(genre: "Drama", percentage: 65),
        TasteProfile(genre: "Sci-Fi", percentage: 40),
        TasteProfile(genre: "Action", percentage: 75),
        TasteProfile(genre: "Comedy", percentage: 50)
    ]
}
