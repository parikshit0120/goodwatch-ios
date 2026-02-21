import Foundation

// ============================================
// ONBOARDING MEMORY SERVICE
// ============================================
// Persists OTT + Language + Duration selections across sessions.
// Users returning within 30 days skip Platform/Language/Duration steps
// and only re-answer the Mood question.
//
// Storage: UserDefaults (keyed per user).
// TTL: 30 days from last save.
// "Start Over" clears memory immediately.
// ============================================

final class GWOnboardingMemory {
    static let shared = GWOnboardingMemory()
    private init() {}

    private let storageKey = "gw_onboarding_memory"
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
    func save(otts: [OTTPlatform], languages: [Language], minDuration: Int, maxDuration: Int, requiresSeries: Bool) {
        let selections = SavedSelections(
            otts: otts,
            languages: languages,
            minDuration: minDuration,
            maxDuration: maxDuration,
            requiresSeries: requiresSeries,
            savedAt: Date()
        )
        if let data = try? JSONEncoder().encode(selections) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        #if DEBUG
        print("[OnboardingMemory] Saved: \(otts.count) OTTs, \(languages.count) languages, \(minDuration)-\(maxDuration)m, series=\(requiresSeries)")
        #endif
    }

    // MARK: - Load

    /// Load saved selections if within TTL. Returns nil if expired or not found.
    func load() -> SavedSelections? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let selections = try? JSONDecoder().decode(SavedSelections.self, from: data) else {
            return nil
        }

        // Check TTL
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

    // MARK: - Check

    /// Returns true if valid (non-expired) saved selections exist.
    var hasSavedSelections: Bool {
        return load() != nil
    }

    // MARK: - Clear

    /// Clear all saved selections. Called on "Start Over".
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)

        #if DEBUG
        print("[OnboardingMemory] Cleared")
        #endif
    }
}
