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

}
