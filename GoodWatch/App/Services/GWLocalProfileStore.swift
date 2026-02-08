import Foundation

// ============================================
// PARTS 8-10: Anonymous Profile & History Persistence
// ============================================
//
// PROBLEM: User completes onboarding, rejects movies, marks some as "Already seen",
// closes app. Next session: App shows the same movies again.
//
// SOLUTION: Local persistence that survives app restarts (even for anonymous users)
//
// STATE ARCHITECTURE:
// ┌─────────────────────────────────────────────────────────────┐
// │                    PERMANENT (UserDefaults)                  │
// ├─────────────────────────────────────────────────────────────┤
// │  • Profile ID (from Keychain)                               │
// │  • Onboarding selections (languages, platforms, moods)      │
// │  • alreadySeenIds[] — movies marked "Already seen"          │
// │  • acceptedMovieIds[] — movies user chose to watch          │
// │  • acceptCount — total accepts (for trust tier)             │
// │  • sessionCount — app opens (for engagement tracking)       │
// └─────────────────────────────────────────────────────────────┘
//
// BEHAVIOR MATRIX:
// | User Action      | Session State | Permanent State           | Next Rec Excludes? |
// |------------------|---------------|---------------------------|-------------------|
// | "Not tonight"    | Add to list   | —                         | Yes (this session)|
// | "Already seen"   | —             | Add to alreadySeenIds     | Yes (forever)     |
// | "Watch on..."    | Clear session | Add to acceptedMovieIds   | Yes (forever)     |
// | Change mood      | Clear session | —                         | Soft reset        |
// | Kill app         | Lost          | Preserved                 | Permanent only    |
// ============================================

/// Persisted anonymous profile data
/// All fields are stored in UserDefaults and survive app restarts
struct GWAnonymousProfile: Codable {
    var id: String                      // UUID from Keychain
    var createdAt: Date
    var lastActiveAt: Date

    // Onboarding selections
    var languages: [String]
    var platforms: [String]
    var moods: [String]

    // Counters for tiered quality gates
    var acceptCount: Int                 // Total movies accepted (Watch on...)
    var sessionCount: Int                // Total app sessions

    // PERMANENT exclusions (survive app restarts)
    var alreadySeenIds: [String]         // Movies marked "Already seen" - NEVER show again
    var acceptedMovieIds: [String]       // Movies watched - NEVER show again

    // Catalog exhaustion check
    var totalExclusionCount: Int {
        alreadySeenIds.count + acceptedMovieIds.count
    }

    static func empty(id: String) -> GWAnonymousProfile {
        GWAnonymousProfile(
            id: id,
            createdAt: Date(),
            lastActiveAt: Date(),
            languages: [],
            platforms: [],
            moods: [],
            acceptCount: 0,
            sessionCount: 0,
            alreadySeenIds: [],
            acceptedMovieIds: []
        )
    }
}

// MARK: - Local Profile Store

/// Manages local persistence of anonymous profile data
/// Uses UserDefaults for cross-session persistence
final class GWLocalProfileStore {
    static let shared = GWLocalProfileStore()
    private init() {}

    private let userDefaultsKey = "gw_anonymous_profile"
    private let maxExclusionListSize = 500 // Cap to prevent storage bloat

    // MARK: - Profile Loading

    /// Load profile from UserDefaults, creating new one if needed
    func loadProfile() -> GWAnonymousProfile {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           var profile = try? JSONDecoder().decode(GWAnonymousProfile.self, from: data) {
            // Update last active time
            profile.lastActiveAt = Date()
            saveProfile(profile)
            return profile
        }

        // Create new profile with Keychain-backed ID
        let id = GWKeychainManager.shared.getOrCreateAnonymousUserId()
        let newProfile = GWAnonymousProfile.empty(id: id)
        saveProfile(newProfile)
        return newProfile
    }

    /// Save profile to UserDefaults
    func saveProfile(_ profile: GWAnonymousProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            #if DEBUG
            print("💾 Saved profile: \(profile.acceptCount) accepts, \(profile.totalExclusionCount) exclusions")
            #endif
        }
    }

    // MARK: - Already Seen (Permanent Exclusion)

    /// Add movie to permanent "already seen" exclusion list
    /// These movies will NEVER be recommended again (until app reinstall)
    func markAlreadySeen(movieId: String) {
        var profile = loadProfile()

        guard !profile.alreadySeenIds.contains(movieId) else { return }

        profile.alreadySeenIds.append(movieId)

        // Cap list size (FIFO removal if over limit)
        if profile.alreadySeenIds.count > maxExclusionListSize {
            profile.alreadySeenIds = Array(profile.alreadySeenIds.suffix(maxExclusionListSize))
        }

        saveProfile(profile)

        #if DEBUG
        print("👁️ Marked as already seen: \(movieId) (total: \(profile.alreadySeenIds.count))")
        #endif
    }

    /// Check if movie is marked as already seen
    func isAlreadySeen(movieId: String) -> Bool {
        let profile = loadProfile()
        return profile.alreadySeenIds.contains(movieId)
    }

    // MARK: - Accepted Movies (Permanent Exclusion)

    /// Add movie to permanent "accepted" exclusion list
    /// User chose to watch this - assume they did, don't recommend again
    func markAccepted(movieId: String) {
        var profile = loadProfile()

        guard !profile.acceptedMovieIds.contains(movieId) else { return }

        profile.acceptedMovieIds.append(movieId)
        profile.acceptCount += 1

        // Cap list size (FIFO removal if over limit)
        if profile.acceptedMovieIds.count > maxExclusionListSize {
            profile.acceptedMovieIds = Array(profile.acceptedMovieIds.suffix(maxExclusionListSize))
        }

        saveProfile(profile)

        #if DEBUG
        print("✅ Marked as accepted: \(movieId) (total accepts: \(profile.acceptCount))")
        #endif
    }

    /// Check if movie was previously accepted
    func wasAccepted(movieId: String) -> Bool {
        let profile = loadProfile()
        return profile.acceptedMovieIds.contains(movieId)
    }

    // MARK: - Combined Exclusion Check

    /// Get ALL permanently excluded movie IDs (already seen + accepted)
    func getPermanentExclusionIds() -> Set<String> {
        let profile = loadProfile()
        return Set(profile.alreadySeenIds + profile.acceptedMovieIds)
    }

    /// Check if movie should be permanently excluded
    func isPermanentlyExcluded(movieId: String) -> Bool {
        let profile = loadProfile()
        return profile.alreadySeenIds.contains(movieId) ||
               profile.acceptedMovieIds.contains(movieId)
    }

    // MARK: - Accept Count (for Tiered Quality Gates)

    /// Get current accept count (for tiered quality gates calculation)
    func getAcceptCount() -> Int {
        return loadProfile().acceptCount
    }

    // MARK: - Session Management

    /// Increment session count (call on app launch)
    func incrementSessionCount() {
        var profile = loadProfile()
        profile.sessionCount += 1
        saveProfile(profile)

        #if DEBUG
        print("📊 Session count: \(profile.sessionCount)")
        #endif
    }

    /// Get current session count
    func getSessionCount() -> Int {
        return loadProfile().sessionCount
    }

    // MARK: - Onboarding Preferences

    /// Save onboarding selections
    func saveOnboardingSelections(languages: [String], platforms: [String], moods: [String] = []) {
        var profile = loadProfile()
        profile.languages = languages
        profile.platforms = platforms
        profile.moods = moods
        saveProfile(profile)

        #if DEBUG
        print("💾 Saved onboarding: languages=\(languages), platforms=\(platforms)")
        #endif
    }

    /// Get saved onboarding selections
    func getOnboardingSelections() -> (languages: [String], platforms: [String], moods: [String]) {
        let profile = loadProfile()
        return (profile.languages, profile.platforms, profile.moods)
    }

    /// Check if onboarding was completed (has at least one platform and language)
    func hasCompletedOnboarding() -> Bool {
        let profile = loadProfile()
        return !profile.languages.isEmpty && !profile.platforms.isEmpty
    }

    // MARK: - Catalog Exhaustion Check

    /// Check if user has exhausted most of the available catalog
    /// Returns true if total exclusions exceed a threshold
    func isNearingCatalogExhaustion(availableCount: Int) -> Bool {
        let profile = loadProfile()
        let remainingCount = availableCount - profile.totalExclusionCount
        // Warn when less than 10 movies remain
        return remainingCount < 10
    }

    // MARK: - Reset

    /// Clear all local profile data (for logout/reset)
    func clearProfile() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        #if DEBUG
        print("🗑️ Cleared local profile")
        #endif
    }

    /// Clear only exclusion lists (for testing/debug)
    func clearExclusions() {
        var profile = loadProfile()
        profile.alreadySeenIds = []
        profile.acceptedMovieIds = []
        // Don't reset acceptCount as it's for quality gates
        saveProfile(profile)
        #if DEBUG
        print("🗑️ Cleared exclusion lists")
        #endif
    }
}

// MARK: - Session Rejection Store (In-Memory Only)

/// Manages session-only rejections ("Not tonight")
/// These are NOT persisted and reset when app restarts or mood changes
final class GWSessionRejectionStore {
    static let shared = GWSessionRejectionStore()
    private init() {}

    /// Movie IDs rejected in current session (NOT persisted)
    private var sessionRejections: Set<String> = []

    /// Add movie to session rejection list
    func addSessionRejection(movieId: String) {
        sessionRejections.insert(movieId)
        #if DEBUG
        print("⏸️ Session rejection: \(movieId) (count: \(sessionRejections.count))")
        #endif
    }

    /// Check if movie was rejected this session
    func isSessionRejected(movieId: String) -> Bool {
        return sessionRejections.contains(movieId)
    }

    /// Get all session rejections
    func getSessionRejections() -> Set<String> {
        return sessionRejections
    }

    /// Clear session rejections (called on mood change or session end)
    func clearSessionRejections() {
        sessionRejections.removeAll()
        #if DEBUG
        print("🔄 Cleared session rejections")
        #endif
    }
}

// MARK: - Combined Exclusion Helper

/// Convenience methods for getting all exclusions
extension GWLocalProfileStore {

    /// Get all exclusions: permanent + session
    /// Use this in the recommendation engine
    func getAllExclusions() -> Set<String> {
        let permanent = getPermanentExclusionIds()
        let session = GWSessionRejectionStore.shared.getSessionRejections()
        return permanent.union(session)
    }

    /// Get exclusion summary for debugging
    func getExclusionSummary() -> String {
        let profile = loadProfile()
        let sessionCount = GWSessionRejectionStore.shared.getSessionRejections().count
        return """
        Exclusion Summary:
        - Already Seen: \(profile.alreadySeenIds.count)
        - Accepted (Watched): \(profile.acceptedMovieIds.count)
        - Session Rejections: \(sessionCount)
        - Total Permanent: \(profile.totalExclusionCount)
        - Accept Count (for gates): \(profile.acceptCount)
        """
    }
}
