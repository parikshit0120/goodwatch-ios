import Foundation

// ============================================
// WATCHLIST MANAGER
// ============================================
// UserDefaults-based persistence for watchlist movie IDs
// Pattern follows TagWeightStore (local-first, per-user)

@MainActor
class WatchlistManager: ObservableObject {

    static let shared = WatchlistManager()

    @Published private(set) var movieIds: Set<String> = []

    private let key = "gw_watchlist_ids"
    private var userPrefix: String = "default"

    private init() {
        load()
    }

    // MARK: - User Scoping

    func setUser(_ userId: String) {
        userPrefix = userId
        load()
    }

    private var storageKey: String {
        "\(key)_\(userPrefix)"
    }

    // MARK: - Public API

    func isInWatchlist(_ movieId: String) -> Bool {
        movieIds.contains(movieId)
    }

    func toggle(_ movieId: String) {
        if movieIds.contains(movieId) {
            movieIds.remove(movieId)
        } else {
            movieIds.insert(movieId)
        }
        save()
    }

    func add(_ movieId: String) {
        movieIds.insert(movieId)
        save()
    }

    func remove(_ movieId: String) {
        movieIds.remove(movieId)
        save()
    }

    var count: Int {
        movieIds.count
    }

    /// Clear watchlist state on sign-out (resets to default scope)
    func clearForSignOut() {
        userPrefix = "default"
        movieIds = []
    }

    // MARK: - Persistence

    private func load() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            movieIds = Set(saved)
        } else {
            movieIds = []
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(movieIds), forKey: storageKey)
    }
}
