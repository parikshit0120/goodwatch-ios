import Foundation
import Security

// ============================================
// SECTION 3: ANONYMOUS AUTH HARDENING
// ============================================
//
// Anonymous users MUST have a stable identity.
// user_id is stored in Keychain and persisted across:
// - App restarts
// - App reinstalls (on same device)
// - iOS updates
// ============================================

final class GWKeychainManager {
    static let shared = GWKeychainManager()
    private init() {}

    private let service = "com.goodwatch.auth"
    private let userIdKey = "gw_anonymous_user_id"

    // MARK: - User ID Management

    /// Get or create a stable anonymous user ID.
    /// This ID persists in Keychain across app restarts and reinstalls.
    func getOrCreateAnonymousUserId() -> String {
        // Try to read existing ID from Keychain
        if let existingId = readFromKeychain(key: userIdKey) {
            #if DEBUG
            print("🔑 Retrieved existing anonymous user ID from Keychain: \(existingId)")
            #endif
            return existingId
        }

        // Generate new ID
        let newId = UUID().uuidString

        // Store in Keychain
        let success = saveToKeychain(key: userIdKey, value: newId)

        #if DEBUG
        if success {
            print("🔑 Created and stored new anonymous user ID in Keychain: \(newId)")
        } else {
            print("🚨 Failed to store anonymous user ID in Keychain")
        }
        #endif

        return newId
    }

    /// Check if anonymous user ID exists in Keychain
    func hasAnonymousUserId() -> Bool {
        return readFromKeychain(key: userIdKey) != nil
    }

    /// Clear anonymous user ID (for logout)
    func clearAnonymousUserId() {
        deleteFromKeychain(key: userIdKey)
        #if DEBUG
        print("🔑 Cleared anonymous user ID from Keychain")
        #endif
    }

    // MARK: - Supabase Session Token

    private let sessionTokenKey = "gw_supabase_session_token"
    private let refreshTokenKey = "gw_supabase_refresh_token"

    /// Store Supabase session token
    func storeSessionToken(_ token: String) {
        _ = saveToKeychain(key: sessionTokenKey, value: token)
    }

    /// Get Supabase session token
    func getSessionToken() -> String? {
        return readFromKeychain(key: sessionTokenKey)
    }

    /// Store Supabase refresh token
    func storeRefreshToken(_ token: String) {
        _ = saveToKeychain(key: refreshTokenKey, value: token)
    }

    /// Get Supabase refresh token
    func getRefreshToken() -> String? {
        return readFromKeychain(key: refreshTokenKey)
    }

    /// Clear all auth tokens
    func clearAllTokens() {
        deleteFromKeychain(key: sessionTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
    }

    // MARK: - Onboarding State

    private let onboardingStepKey = "gw_onboarding_step"

    /// Store last completed onboarding step
    func storeOnboardingStep(_ step: Int) {
        _ = saveToKeychain(key: onboardingStepKey, value: String(step))
    }

    /// Get last completed onboarding step for resume
    func getOnboardingStep() -> Int {
        guard let stepString = readFromKeychain(key: onboardingStepKey),
              let step = Int(stepString) else {
            return 0
        }
        return step
    }

    /// Clear onboarding state
    func clearOnboardingState() {
        deleteFromKeychain(key: onboardingStepKey)
    }

    // MARK: - Private Keychain Operations

    private func saveToKeychain(key: String, value: String) -> Bool {
        let data = Data(value.utf8)

        // Delete existing item first
        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - UserService Integration

extension GWKeychainManager {
    /// Get stable user ID for all Supabase operations.
    /// Uses Keychain-backed anonymous ID if not authenticated.
    func getStableUserId(authenticatedUserId: UUID?) -> String {
        if let authId = authenticatedUserId {
            return authId.uuidString
        }
        return getOrCreateAnonymousUserId()
    }
}
