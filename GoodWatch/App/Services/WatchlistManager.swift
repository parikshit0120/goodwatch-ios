import Foundation

// ============================================
// WATCHLIST MANAGER
// ============================================
// UserDefaults-based persistence for watchlist movie IDs.
// Supabase sync: reads on launch, writes on every change.
// UserDefaults is the primary read source during a session.
// Supabase is the backup/recovery source for reinstalls.

@MainActor
class WatchlistManager: ObservableObject {

    static let shared = WatchlistManager()

    @Published private(set) var movieIds: Set<String> = []

    private let key = "gw_watchlist_ids"
    private var userPrefix: String = "default"
    private let saveQueue = DispatchQueue(label: "com.goodwatch.watchlist.save", qos: .utility)

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
            save()
            removeFromRemote(movieId: movieId)
        } else {
            movieIds.insert(movieId)
            save()
            pushToRemote(movieId: movieId)
        }
    }

    func add(_ movieId: String) {
        movieIds.insert(movieId)
        save()
        pushToRemote(movieId: movieId)
    }

    func remove(_ movieId: String) {
        movieIds.remove(movieId)
        save()
        removeFromRemote(movieId: movieId)
    }

    var count: Int {
        movieIds.count
    }

    /// Clear watchlist state on sign-out (resets to default scope)
    func clearForSignOut() {
        userPrefix = "default"
        movieIds = []
    }

    // MARK: - Persistence (Local)

    private func load() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            movieIds = Set(saved)
        } else {
            movieIds = []
        }
    }

    private func save() {
        let snapshot = Array(movieIds)
        let key = storageKey
        saveQueue.async {
            UserDefaults.standard.set(snapshot, forKey: key)
        }
    }

    // MARK: - Supabase Sync

    /// Sync watchlist from Supabase on app launch.
    /// - If local is empty but remote has data: use remote (reinstall recovery)
    /// - If local has data and remote has data: merge (union)
    /// - If local has data and remote is empty: push local to remote (first-time sync)
    func syncFromRemote() async {
        guard SupabaseConfig.isConfigured else { return }
        guard let userId = resolveUserId() else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/user_watchlist?user_id=eq.\(userId)&removed_at=is.null&select=movie_id"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                #if DEBUG
                print("[WatchlistSync] HTTP error fetching remote watchlist")
                #endif
                return
            }

            struct WatchlistRow: Decodable {
                let movie_id: String
            }
            let rows = try JSONDecoder().decode([WatchlistRow].self, from: data)
            let remoteIds = Set(rows.map { $0.movie_id })

            #if DEBUG
            print("[WatchlistSync] Remote: \(remoteIds.count) items, Local: \(movieIds.count) items")
            #endif

            let localIds = movieIds

            if localIds.isEmpty && !remoteIds.isEmpty {
                // Reinstall recovery: use remote
                movieIds = remoteIds
                save()
                #if DEBUG
                print("[WatchlistSync] Restored \(remoteIds.count) items from remote (reinstall recovery)")
                #endif
            } else if !localIds.isEmpty && !remoteIds.isEmpty {
                // Merge: union of both sets
                let merged = localIds.union(remoteIds)
                movieIds = merged
                save()
                // Push any local-only items to remote
                let localOnly = localIds.subtracting(remoteIds)
                for id in localOnly {
                    pushToRemote(movieId: id)
                }
                #if DEBUG
                print("[WatchlistSync] Merged: \(merged.count) items (\(localOnly.count) pushed to remote)")
                #endif
            } else if !localIds.isEmpty && remoteIds.isEmpty {
                // First-time sync: push all local to remote
                for id in localIds {
                    pushToRemote(movieId: id)
                }
                #if DEBUG
                print("[WatchlistSync] First-time sync: pushed \(localIds.count) items to remote")
                #endif
            }
            // If both empty, nothing to do
        } catch {
            #if DEBUG
            print("[WatchlistSync] Fetch failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Remote Write-Through

    /// Fire-and-forget upsert to Supabase when a movie is added.
    private func pushToRemote(movieId: String) {
        guard SupabaseConfig.isConfigured else { return }
        guard let userId = resolveUserId() else { return }

        Task.detached(priority: .utility) {
            let urlString = "\(SupabaseConfig.url)/rest/v1/user_watchlist"
            guard let url = URL(string: urlString) else { return }

            let now = ISO8601DateFormatter().string(from: Date())
            let body: [String: Any] = [
                "user_id": userId,
                "movie_id": movieId,
                "added_at": now,
                "removed_at": NSNull()
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.timeoutInterval = 5.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                #if DEBUG
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    print("[WatchlistSync] Push failed for \(movieId): HTTP \(http.statusCode)")
                }
                #endif
            } catch {
                #if DEBUG
                print("[WatchlistSync] Push error for \(movieId): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Fire-and-forget soft-delete in Supabase when a movie is removed.
    private func removeFromRemote(movieId: String) {
        guard SupabaseConfig.isConfigured else { return }
        guard let userId = resolveUserId() else { return }

        Task.detached(priority: .utility) {
            let urlString = "\(SupabaseConfig.url)/rest/v1/user_watchlist?user_id=eq.\(userId)&movie_id=eq.\(movieId)"
            guard let url = URL(string: urlString) else { return }

            let now = ISO8601DateFormatter().string(from: Date())
            let body: [String: Any] = ["removed_at": now]

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.timeoutInterval = 5.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                #if DEBUG
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    print("[WatchlistSync] Remove failed for \(movieId): HTTP \(http.statusCode)")
                }
                #endif
            } catch {
                #if DEBUG
                print("[WatchlistSync] Remove error for \(movieId): \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - User ID Resolution

    private func resolveUserId() -> String? {
        // Try UserService cached user ID first
        if let cachedId = UserService.shared.cachedUserId {
            return cachedId.uuidString
        }
        // Fallback to Keychain anonymous ID
        let keychainId = GWKeychainManager.shared.getOrCreateAnonymousUserId()
        return keychainId.isEmpty ? nil : keychainId
    }
}
