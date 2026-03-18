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

    // MARK: - Onboarding State
    // Stored in UserDefaults (NOT Keychain) so it resets on app uninstall/reinstall.
    // Keychain persists across reinstalls which caused users to skip onboarding.

    private let onboardingStepKey = "gw_onboarding_step"
    private let keychainMigratedKey = "gw_onboarding_migrated_to_ud"

    /// Store last completed onboarding step (UserDefaults — clears on reinstall)
    func storeOnboardingStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: onboardingStepKey)
    }

    /// Mark onboarding as complete (step 6). Call at the moment the LAST
    /// preference step is confirmed, BEFORE navigation or recommendation fetch.
    /// Testable entry point — both View code and unit tests call this.
    func completeOnboarding() {
        UserDefaults.standard.set(6, forKey: onboardingStepKey)
    }

    /// Get last completed onboarding step for resume (UserDefaults — clears on reinstall)
    func getOnboardingStep() -> Int {
        return UserDefaults.standard.integer(forKey: onboardingStepKey)
    }

    /// One-time migration: remove stale onboarding step from Keychain on existing devices.
    /// Call once at app launch.
    func migrateOnboardingFromKeychain() {
        guard !UserDefaults.standard.bool(forKey: keychainMigratedKey) else { return }
        // Delete old Keychain entry if it exists
        deleteFromKeychain(key: onboardingStepKey)
        UserDefaults.standard.set(true, forKey: keychainMigratedKey)
        #if DEBUG
        print("[GWKeychain] Migrated: removed onboarding step from Keychain")
        #endif
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
