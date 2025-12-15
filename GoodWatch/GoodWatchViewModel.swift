import SwiftUI
import Foundation

// MARK: - Main ViewModel
class GoodWatchViewModel: ObservableObject {
    // MARK: - Published State
    @Published var watchlist: [WatchlistItem] = []
    @Published var likedMovies: [Movie] = []
    @Published var excludedMovies: [Movie] = []
    @Published var selectedMoods: Set<String> = []
    @Published var userStats: UserStats = UserStats()
    @Published var hasCompletedOnboarding: Bool = false
    
    // Keys for persistence
    private let watchlistKey = "goodwatch_watchlist"
    private let likedKey = "goodwatch_liked"
    private let excludedKey = "goodwatch_excluded"
    private let moodsKey = "goodwatch_moods"
    private let statsKey = "goodwatch_stats"
    
    init() {
        loadData()
    }
    
    // MARK: - Watchlist Actions
    func addToWatchlist(_ movie: Movie) {
        guard !isInWatchlist(movie) else { return }
        let item = WatchlistItem(movie: movie, isWatched: false, addedAt: Date())
        watchlist.insert(item, at: 0)
        updateStats(action: .addedToWatchlist)
        saveData()
    }
    
    func removeFromWatchlist(_ movie: Movie) {
        watchlist.removeAll { $0.movie.id == movie.id }
        saveData()
    }
    
    func markAsWatched(_ movie: Movie) {
        if let index = watchlist.firstIndex(where: { $0.movie.id == movie.id }) {
            watchlist[index].isWatched = true
            watchlist[index].watchedAt = Date()
            updateStats(action: .watched)
            saveData()
        }
    }
    
    func markAsUnwatched(_ movie: Movie) {
        if let index = watchlist.firstIndex(where: { $0.movie.id == movie.id }) {
            watchlist[index].isWatched = false
            watchlist[index].watchedAt = nil
            saveData()
        }
    }
    
    func isInWatchlist(_ movie: Movie) -> Bool {
        watchlist.contains { $0.movie.id == movie.id }
    }
    
    // MARK: - Like/Skip Actions
    func likeMovie(_ movie: Movie) {
        guard !likedMovies.contains(where: { $0.id == movie.id }) else { return }
        likedMovies.append(movie)
        addToWatchlist(movie) // Liked movies go to watchlist
        updateStats(action: .liked)
        saveData()
    }
    
    func skipMovie(_ movie: Movie) {
        guard !excludedMovies.contains(where: { $0.id == movie.id }) else { return }
        excludedMovies.append(movie)
        updateStats(action: .swiped)
        saveData()
    }
    
    // MARK: - Mood Actions
    func toggleMood(_ mood: String) {
        if selectedMoods.contains(mood) {
            selectedMoods.remove(mood)
        } else {
            selectedMoods.insert(mood)
        }
        saveData()
    }
    
    func setMoods(_ moods: Set<String>) {
        selectedMoods = moods
        saveData()
    }
    
    func clearMoods() {
        selectedMoods.removeAll()
        saveData()
    }
    
    func shuffleMoods(from available: [Mood]) {
        selectedMoods.removeAll()
        let randomMoods = available.shuffled().prefix(2)
        randomMoods.forEach { selectedMoods.insert($0.name) }
        saveData()
    }
    
    // MARK: - Filtered Data
    var toWatchList: [WatchlistItem] {
        watchlist.filter { !$0.isWatched }
    }
    
    var watchedList: [WatchlistItem] {
        watchlist.filter { $0.isWatched }
    }
    
    func getDiscoveryMovies(allMovies: [Movie]) -> [Movie] {
        // Filter out already liked/excluded movies
        let seenIds = Set(likedMovies.map { $0.id } + excludedMovies.map { $0.id })
        return allMovies.filter { !seenIds.contains($0.id) }
    }
    
    // MARK: - Stats
    enum StatAction {
        case liked, swiped, addedToWatchlist, watched
    }
    
    private func updateStats(action: StatAction) {
        switch action {
        case .liked:
            userStats.totalSwipes += 1
            userStats.moviesDiscovered += 1
        case .swiped:
            userStats.totalSwipes += 1
        case .addedToWatchlist:
            break // Already counted in liked
        case .watched:
            userStats.watchedThisMonth += 1
            updateStreak()
        }
        saveData()
    }
    
    private func updateStreak() {
        // Simple streak logic - in production would check actual dates
        userStats.dayStreak += 1
        if userStats.dayStreak > userStats.bestStreak {
            userStats.bestStreak = userStats.dayStreak
        }
    }
    
    // MARK: - Persistence
    private func saveData() {
        // Save watchlist
        if let encoded = try? JSONEncoder().encode(watchlist) {
            UserDefaults.standard.set(encoded, forKey: watchlistKey)
        }
        
        // Save liked movies
        if let encoded = try? JSONEncoder().encode(likedMovies) {
            UserDefaults.standard.set(encoded, forKey: likedKey)
        }
        
        // Save excluded movies
        if let encoded = try? JSONEncoder().encode(excludedMovies) {
            UserDefaults.standard.set(encoded, forKey: excludedKey)
        }
        
        // Save moods
        UserDefaults.standard.set(Array(selectedMoods), forKey: moodsKey)
        
        // Save stats
        if let encoded = try? JSONEncoder().encode(userStats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadData() {
        // Load watchlist
        if let data = UserDefaults.standard.data(forKey: watchlistKey),
           let decoded = try? JSONDecoder().decode([WatchlistItem].self, from: data) {
            watchlist = decoded
        }
        
        // Load liked movies
        if let data = UserDefaults.standard.data(forKey: likedKey),
           let decoded = try? JSONDecoder().decode([Movie].self, from: data) {
            likedMovies = decoded
        }
        
        // Load excluded movies
        if let data = UserDefaults.standard.data(forKey: excludedKey),
           let decoded = try? JSONDecoder().decode([Movie].self, from: data) {
            excludedMovies = decoded
        }
        
        // Load moods
        if let moods = UserDefaults.standard.array(forKey: moodsKey) as? [String] {
            selectedMoods = Set(moods)
        }
        
        // Load stats
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            userStats = decoded
        }
    }
    
    // MARK: - Reset (for testing/sign out)
    func resetAllData() {
        watchlist = []
        likedMovies = []
        excludedMovies = []
        selectedMoods = []
        userStats = UserStats()
        
        UserDefaults.standard.removeObject(forKey: watchlistKey)
        UserDefaults.standard.removeObject(forKey: likedKey)
        UserDefaults.standard.removeObject(forKey: excludedKey)
        UserDefaults.standard.removeObject(forKey: moodsKey)
        UserDefaults.standard.removeObject(forKey: statsKey)
    }
}
