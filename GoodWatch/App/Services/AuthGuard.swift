import Foundation

// ============================================
// PHASE 3: AUTH & IDENTITY GUARD
// ============================================
//
// Rules enforced:
// - User ID MUST exist before onboarding completes
// - Every selection updates user_profiles
// - No user → no recommendations
//
// Auth Methods (priority order):
// 1. Apple Sign-In (mandatory for iOS)
// 2. Gmail (optional)
// 3. Anonymous UUID fallback (device ID)
// ============================================

final class AuthGuard {
    static let shared = AuthGuard()
    private init() {}

    /// Returns true if user is properly authenticated (has valid user ID)
    var isAuthenticated: Bool {
        UserService.shared.currentUser != nil
    }

    /// Returns the current user ID, or nil if not authenticated
    var currentUserId: UUID? {
        UserService.shared.currentUser?.id
    }

    /// Returns the current user ID as string for Supabase operations
    var currentUserIdString: String {
        currentUserId?.uuidString ?? "anonymous"
    }

    // ============================================
    // RULE: User ID MUST exist before onboarding completes
    // ============================================

    /// Ensure user exists before proceeding with onboarding.
    /// If no user exists, creates anonymous user.
    /// NEVER returns nil - will create anonymous user as fallback.
    func ensureUserExistsBeforeOnboarding() async -> UUID {
        // Check if user already exists
        if let userId = currentUserId {
            #if DEBUG
            print("✅ User exists: \(userId)")
            #endif
            return userId
        }

        // Create anonymous user as fallback
        do {
            let user = try await UserService.shared.signInAnonymously()
            #if DEBUG
            print("✅ Anonymous user created: \(user.id)")
            #endif
            return user.id
        } catch {
            // If Supabase fails, use device ID as fallback (local-only)
            let deviceId = UserService.shared.deviceId
            let fallbackId = UUID(uuidString: deviceId) ?? UUID()

            #if DEBUG
            print("⚠️ Supabase auth failed, using device ID: \(fallbackId)")
            #endif

            // In PROD, log this failure
            print("🚨 AUTH FALLBACK: Using device ID \(fallbackId)")

            return fallbackId
        }
    }

    /// Check if user can proceed to recommendations
    /// Returns (canProceed, userId, errorMessage)
    func canProceedToRecommendations() -> (canProceed: Bool, userId: UUID?, errorMessage: String?) {
        guard let userId = currentUserId else {
            return (false, nil, "No user ID. Please sign in or continue as guest.")
        }

        // Additional checks could go here (e.g., profile completeness)
        return (true, userId, nil)
    }

    // ============================================
    // RULE: Every selection updates user_profiles
    // ============================================

    /// Update user profile with mood selection
    func recordMoodSelection(_ mood: String) async {
        guard isAuthenticated else {
            #if DEBUG
            print("⚠️ Cannot record mood - no user")
            #endif
            return
        }

        do {
            try await UserService.shared.updateMoodPreference(mood)
            #if DEBUG
            print("✅ Mood recorded: \(mood)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to record mood: \(error)")
            #endif
        }
    }

    /// Update user profile with platform selection
    func recordPlatformSelection(_ platforms: [String]) async {
        guard isAuthenticated else { return }

        do {
            try await UserService.shared.updatePlatforms(platforms)
            #if DEBUG
            print("✅ Platforms recorded: \(platforms)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to record platforms: \(error)")
            #endif
        }
    }

    /// Update user profile with runtime preference
    func recordRuntimeSelection(maxRuntime: Int, range: RuntimeRange) async {
        guard isAuthenticated else { return }

        do {
            try await UserService.shared.updateRuntimePreference(maxRuntime: maxRuntime, range: range)
            #if DEBUG
            print("✅ Runtime recorded: \(maxRuntime)min (\(range))")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to record runtime: \(error)")
            #endif
        }
    }

    /// Update user profile with language preference
    func recordLanguageSelection(_ languages: [String]) async {
        guard isAuthenticated else { return }

        do {
            try await UserService.shared.updateLanguages(languages)
            #if DEBUG
            print("✅ Languages recorded: \(languages)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to record languages: \(error)")
            #endif
        }
    }

    // ============================================
    // RULE: No user → no recommendations
    // ============================================

    /// Guard function that should be called before any recommendation request.
    /// Returns nil if user is not properly authenticated.
    func guardRecommendation() -> UUID? {
        guard let userId = currentUserId else {
            #if DEBUG
            print("🚫 RECOMMENDATION BLOCKED: No user ID")
            #endif

            // Log this in production for monitoring
            print("🚨 PROD: Recommendation blocked - no user ID")

            return nil
        }

        return userId
    }
}

// MARK: - RootFlowView Integration Helper

extension AuthGuard {
    /// Call this at the start of the recommendation flow
    func prepareForRecommendation() async -> (success: Bool, userId: UUID) {
        let userId = await ensureUserExistsBeforeOnboarding()
        return (true, userId)
    }
}
