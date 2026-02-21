import Foundation

// ============================================
// INTERACTION POINTS SERVICE
// ============================================
// Tracks cumulative interaction points per user.
// Points determine how many picks the user sees (5 -> 4 -> 3 -> 2 -> 1).
// Points are a one-way ratchet: they never decrease.
//
// Storage: UserDefaults (local) + Supabase user_profiles.interaction_points (remote).
// On launch: reconcile local vs remote (take higher value).
// On interaction: increment locally + fire-and-forget to Supabase.
// ============================================

// MARK: - Rejection Reason

enum GWCardRejectionReason: String, Codable {
    case notInterested = "not_interested"
    case alreadySeen = "already_seen"
}

// MARK: - Interaction Points Service

final class GWInteractionPoints {
    static let shared = GWInteractionPoints()
    private init() {}

    private let pointsKeyPrefix = "gw_interaction_points_"
    private let tierKeyPrefix = "gw_max_pick_tier_reached_"

    private var currentUserId: String?

    // MARK: - User Setup

    func setUser(_ userId: String) {
        currentUserId = userId

        #if DEBUG
        // Override interaction points from launch arguments (screenshot testing)
        let debugPoints = UserDefaults.standard.integer(forKey: "gw_debug_interaction_points")
        if debugPoints > 0 {
            let key = "\(pointsKeyPrefix)\(userId)"
            UserDefaults.standard.set(debugPoints, forKey: key)
            print("[CAROUSEL] DEBUG: Overriding interaction points to \(debugPoints)")
        }
        #endif
    }

    // MARK: - Points Access

    var currentPoints: Int {
        guard let userId = currentUserId else { return 0 }
        return UserDefaults.standard.integer(forKey: "\(pointsKeyPrefix)\(userId)")
    }

    // MARK: - Add Points

    func add(_ points: Int) {
        guard let userId = currentUserId, points > 0 else { return }
        let key = "\(pointsKeyPrefix)\(userId)"
        let current = UserDefaults.standard.integer(forKey: key)
        let newTotal = current + points
        UserDefaults.standard.set(newTotal, forKey: key)

        // Update max tier reached (one-way ratchet)
        let currentTier = pickCount(forInteractionPoints: newTotal)
        let tierKey = "\(tierKeyPrefix)\(userId)"
        let maxTierReached = UserDefaults.standard.integer(forKey: tierKey)
        if maxTierReached == 0 || currentTier < maxTierReached {
            // Lower pick count = higher tier (5 is lowest tier, 1 is highest)
            UserDefaults.standard.set(currentTier, forKey: tierKey)
        }

        // Fire-and-forget sync to Supabase
        let total = newTotal
        Task {
            await syncToSupabase(userId: userId, points: total)
        }

        #if DEBUG
        print("GW Points: +\(points) = \(newTotal) total (tier: \(currentTier) picks)")
        #endif
    }

    // MARK: - Pick Count

    func pickCount(forInteractionPoints points: Int) -> Int {
        switch points {
        case 0...19:    return 5   // ~3-4 sessions
        case 20...49:   return 4   // ~5-8 sessions
        case 50...99:   return 3   // ~9-15 sessions
        case 100...159: return 2   // ~16-25 sessions
        default:        return 1   // ~26+ sessions (earned mastery)
        }
    }

    /// Returns the effective pick count for the current user.
    /// Respects the one-way ratchet: never shows more picks than the current tier.
    var effectivePickCount: Int {
        guard let userId = currentUserId else { return 5 }
        let points = currentPoints
        let currentTier = pickCount(forInteractionPoints: points)

        // Check max tier reached (ratchet)
        let tierKey = "\(tierKeyPrefix)\(userId)"
        let maxTierReached = UserDefaults.standard.integer(forKey: tierKey)

        if maxTierReached == 0 {
            // Never stored — use current tier
            return currentTier
        }

        // Return the lower pick count (higher tier)
        return min(currentTier, maxTierReached)
    }

    // MARK: - Reconciliation

    /// On app launch, reconcile local vs remote points (take higher value).
    func reconcile(userId: String) async {
        setUser(userId)
        let localPoints = currentPoints

        do {
            let remotePoints = try await fetchRemotePoints(userId: userId)
            if remotePoints > localPoints {
                let key = "\(pointsKeyPrefix)\(userId)"
                UserDefaults.standard.set(remotePoints, forKey: key)
                #if DEBUG
                print("GW Points: Reconciled remote > local (\(remotePoints) > \(localPoints))")
                #endif
            } else if localPoints > remotePoints {
                await syncToSupabase(userId: userId, points: localPoints)
                #if DEBUG
                print("GW Points: Reconciled local > remote (\(localPoints) > \(remotePoints))")
                #endif
            }
        } catch {
            #if DEBUG
            print("GW Points: Reconciliation failed: \(error)")
            #endif
        }
    }

    // MARK: - Supabase Sync

    private func syncToSupabase(userId: String, points: Int) async {
        guard SupabaseConfig.isConfigured else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/user_profiles?user_id=eq.\(userId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = ["interaction_points": points]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await GWNetworkSession.shared.data(for: request)
    }

    #if DEBUG
    /// Reset interaction points for testing. Debug builds only.
    func resetForTesting(userId: String) {
        UserDefaults.standard.set(0, forKey: "\(pointsKeyPrefix)\(userId)")
        UserDefaults.standard.removeObject(forKey: "\(tierKeyPrefix)\(userId)")
        print("[CAROUSEL] Points and tier reset for user: \(userId)")
    }
    #endif

    private func fetchRemotePoints(userId: String) async throws -> Int {
        let urlString = "\(SupabaseConfig.url)/rest/v1/user_profiles?user_id=eq.\(userId)&select=interaction_points"
        guard let url = URL(string: urlString) else { return 0 }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await GWNetworkSession.shared.data(for: request)

        struct PointsRow: Codable {
            let interaction_points: Int?
        }

        let rows = try JSONDecoder().decode([PointsRow].self, from: data)
        return rows.first?.interaction_points ?? 0
    }
}
