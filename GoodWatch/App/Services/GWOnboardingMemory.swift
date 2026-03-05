import Foundation
import Security

// ============================================
// ONBOARDING MEMORY SERVICE
// ============================================
// Persists OTT + Language + Duration selections across sessions.
// Users returning within 30 days skip Platform/Language/Duration steps
// and only re-answer the Mood question.
//
// Storage: UserDefaults (primary) + Keychain (backup).
// Keychain backup survives UserDefaults wipes (but NOT reinstalls
// since we use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly).
// TTL: 30 days from last save.
// ============================================

final class GWOnboardingMemory {
    static let shared = GWOnboardingMemory()
    private init() {}

    private let storageKey = "gw_onboarding_memory"
    private let keychainKey = "gw_onboarding_memory_backup"
    private let keychainService = "com.goodwatch.onboarding"
    private let ttlDays: Int = 30

    // MARK: - Data Model

    struct SavedSelections: Codable {
        let otts: [OTTPlatform]
        let languages: [Language]
        let minDuration: Int
        let maxDuration: Int
        let requiresSeries: Bool
        let savedAt: Date
    }

    // MARK: - Save

    /// Save current onboarding selections. Called when onboarding completes (step 6).
    /// Writes to both UserDefaults (primary) and Keychain (backup).
    func save(otts: [OTTPlatform], languages: [Language], minDuration: Int, maxDuration: Int, requiresSeries: Bool) {
        let selections = SavedSelections(
            otts: otts,
            languages: languages,
            minDuration: minDuration,
            maxDuration: maxDuration,
            requiresSeries: requiresSeries,
            savedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(selections) else { return }

        // Primary: UserDefaults
        UserDefaults.standard.set(data, forKey: storageKey)

        // Backup: Keychain
        saveToKeychain(data: data)

        #if DEBUG
        print("[OnboardingMemory] Saved: \(otts.count) OTTs, \(languages.count) languages, \(minDuration)-\(maxDuration)m, series=\(requiresSeries)")
        #endif
    }

    // MARK: - Load

    /// Load saved selections if within TTL. Returns nil if expired or not found.
    /// Tries UserDefaults first, falls back to Keychain backup.
    func load() -> SavedSelections? {
        // Try UserDefaults first
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let selections = try? JSONDecoder().decode(SavedSelections.self, from: data) {
            return validateTTL(selections)
        }

        // Fallback: Keychain backup
        if let data = loadFromKeychain(),
           let selections = try? JSONDecoder().decode(SavedSelections.self, from: data) {
            #if DEBUG
            print("[OnboardingMemory] Restored from Keychain backup")
            #endif
            // Re-populate UserDefaults from Keychain backup
            UserDefaults.standard.set(data, forKey: storageKey)
            return validateTTL(selections)
        }

        return nil
    }

    // MARK: - Check

    /// Returns true if valid (non-expired) saved selections exist.
    var hasSavedSelections: Bool {
        return load() != nil
    }

    // MARK: - Clear

    /// Clear all saved selections. Only called on --reset-onboarding (debug).
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        deleteFromKeychain()

        #if DEBUG
        print("[OnboardingMemory] Cleared")
        #endif
    }

    // MARK: - Private

    private func validateTTL(_ selections: SavedSelections) -> SavedSelections? {
        let daysSinceSave = Calendar.current.dateComponents([.day], from: selections.savedAt, to: Date()).day ?? 999
        if daysSinceSave > ttlDays {
            #if DEBUG
            print("[OnboardingMemory] Expired (\(daysSinceSave) days old), clearing")
            #endif
            clear()
            return nil
        }

        #if DEBUG
        print("[OnboardingMemory] Loaded: \(selections.otts.count) OTTs, \(selections.languages.count) languages, \(daysSinceSave) days old")
        #endif

        return selections
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(data: Data) {
        // Delete existing first
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}
