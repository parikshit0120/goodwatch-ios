import Foundation

// ============================================
// OTT-LANGUAGE AVAILABILITY MAPPING
// ============================================
//
// This service manages the availability matrix of OTT platforms
// and languages. Some platforms only have content in certain
// languages (e.g., Apple TV+ has minimal Hindi content).
//
// Usage:
// - Query available languages for selected platforms
// - Disable unavailable language options in UI
// - Show specific error messages when no content matches
// ============================================

/// Defines content availability levels for OTT + Language combinations
enum ContentAvailability: Int, Comparable {
    /// No content available in this language on this platform
    case none = 0
    /// Very limited content (<20 titles typically)
    case veryLimited = 1
    /// Some content available (20-100 titles)
    case limited = 2
    /// Good amount of content available (100+ titles)
    case good = 3
    /// Extensive catalog in this language
    case extensive = 4

    static func < (lhs: ContentAvailability, rhs: ContentAvailability) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var isUsable: Bool {
        self >= .limited
    }

    var displayMessage: String {
        switch self {
        case .none:
            return "Not available"
        case .veryLimited:
            return "Very limited selection"
        case .limited:
            return "Limited selection"
        case .good:
            return "Good selection"
        case .extensive:
            return "Extensive catalog"
        }
    }
}

/// Service to check OTT platform + language content availability
final class OTTLanguageAvailability {
    static let shared = OTTLanguageAvailability()
    private init() {}

    // ============================================
    // AVAILABILITY MATRIX
    // ============================================
    // This matrix defines content availability for each OTT + Language combo.
    // Update this based on actual catalog analysis.
    //
    // Key:
    // - .extensive: Platform's primary language or major market (Netflix Hindi, Prime Hindi/English)
    // - .good: Strong secondary catalog (Netflix English in India)
    // - .limited: Some content but not comprehensive (Zee5 English)
    // - .veryLimited: Minimal content, likely only a handful of titles (Apple TV+ Hindi)
    // - .none: No content in this language
    // ============================================

    private let availabilityMatrix: [OTTPlatform: [Language: ContentAvailability]] = [
        .netflix: [
            .english: .extensive,
            .hindi: .extensive,
            .tamil: .extensive,
            .telugu: .extensive,
            .malayalam: .good,
            .kannada: .good,
            .marathi: .good,
            .korean: .extensive,
            .spanish: .extensive
        ],
        .prime: [
            .english: .extensive,
            .hindi: .extensive,
            .tamil: .extensive,
            .telugu: .extensive,
            .malayalam: .extensive,
            .kannada: .good,
            .marathi: .good,
            .korean: .good,
            .spanish: .good
        ],
        .jioHotstar: [
            .english: .good,
            .hindi: .extensive,
            .tamil: .extensive,
            .telugu: .extensive,
            .malayalam: .good,
            .kannada: .good,
            .marathi: .good,
            .korean: .limited,
            .spanish: .limited
        ],
        .appleTV: [
            .english: .extensive,
            .hindi: .veryLimited,
            .tamil: .veryLimited,
            .telugu: .veryLimited,
            .malayalam: .none,
            .kannada: .none,
            .marathi: .none,
            .korean: .good,
            .spanish: .good
        ],
        .sonyLIV: [
            .english: .limited,
            .hindi: .extensive,
            .tamil: .good,
            .telugu: .good,
            .malayalam: .limited,
            .kannada: .limited,
            .marathi: .good,
            .korean: .veryLimited,
            .spanish: .none
        ],
        .zee5: [
            .english: .veryLimited,
            .hindi: .extensive,
            .tamil: .good,
            .telugu: .good,
            .malayalam: .good,
            .kannada: .good,
            .marathi: .good,
            .korean: .veryLimited,
            .spanish: .none
        ]
    ]

    // ============================================
    // PUBLIC API
    // ============================================

    /// Get content availability for a specific OTT + Language combination
    func availability(for platform: OTTPlatform, language: Language) -> ContentAvailability {
        availabilityMatrix[platform]?[language] ?? .none
    }

    /// Check if a language has usable content on ANY of the selected platforms
    func isLanguageAvailable(_ language: Language, onPlatforms platforms: [OTTPlatform]) -> Bool {
        guard !platforms.isEmpty else { return true }

        return platforms.contains { platform in
            availability(for: platform, language: language).isUsable
        }
    }

    /// Get combined availability for a language across all selected platforms
    /// Returns the BEST availability among all platforms
    func bestAvailability(for language: Language, onPlatforms platforms: [OTTPlatform]) -> ContentAvailability {
        guard !platforms.isEmpty else { return .extensive }

        return platforms.map { availability(for: $0, language: language) }.max() ?? .none
    }

    /// Get list of languages that have usable content on selected platforms
    func availableLanguages(for platforms: [OTTPlatform]) -> [Language] {
        Language.allCases.filter { isLanguageAvailable($0, onPlatforms: platforms) }
    }

    /// Get list of languages that have LIMITED or NO content on selected platforms
    func limitedLanguages(for platforms: [OTTPlatform]) -> [Language] {
        Language.allCases.filter { !isLanguageAvailable($0, onPlatforms: platforms) }
    }

    /// Get detailed availability info for all languages on selected platforms
    func availabilityReport(for platforms: [OTTPlatform]) -> [(language: Language, availability: ContentAvailability, platforms: [(OTTPlatform, ContentAvailability)])] {
        Language.allCases.map { language in
            let platformDetails = platforms.map { platform in
                (platform, availability(for: platform, language: language))
            }
            let best = bestAvailability(for: language, onPlatforms: platforms)
            return (language, best, platformDetails)
        }
    }

    /// Get a user-friendly message explaining why a language isn't available
    func unavailabilityMessage(for language: Language, onPlatforms platforms: [OTTPlatform]) -> String {
        guard !platforms.isEmpty else {
            return "Select at least one streaming platform"
        }

        let availability = bestAvailability(for: language, onPlatforms: platforms)
        let platformNames = platforms.map { $0.displayName }.joined(separator: ", ")

        switch availability {
        case .none:
            return "\(language.displayName) content is not available on \(platformNames)"
        case .veryLimited:
            return "Very limited \(language.displayName) content on \(platformNames)"
        case .limited, .good, .extensive:
            return "" // Should not show message for available languages
        }
    }

    /// Check if the current OTT + Language combination has enough content
    /// Returns nil if OK, or an error message if problematic
    func validateSelection(platforms: [OTTPlatform], languages: [Language]) -> String? {
        guard !platforms.isEmpty else { return nil }
        guard !languages.isEmpty else { return nil }

        // Check if ANY language has usable content on ANY platform
        let hasUsableContent = languages.contains { language in
            isLanguageAvailable(language, onPlatforms: platforms)
        }

        if !hasUsableContent {
            // All selected languages have limited content on all selected platforms
            let platformNames = platforms.map { $0.displayName }.joined(separator: " and ")
            let languageNames = languages.map { $0.displayName }.joined(separator: " and ")
            return "\(languageNames) content is very limited on \(platformNames). You may not find many recommendations."
        }

        return nil
    }
}

// ============================================
// CONVENIENCE EXTENSIONS
// ============================================

extension OTTPlatform {
    /// Get supported languages for this platform (with usable content)
    var supportedLanguages: [Language] {
        OTTLanguageAvailability.shared.availableLanguages(for: [self])
    }

    /// Check if this platform has usable content in a specific language
    func supports(language: Language) -> Bool {
        OTTLanguageAvailability.shared.availability(for: self, language: language).isUsable
    }
}

extension Language {
    /// Get platforms that have usable content in this language
    func supportedPlatforms(from available: [OTTPlatform]) -> [OTTPlatform] {
        available.filter { platform in
            OTTLanguageAvailability.shared.availability(for: platform, language: self).isUsable
        }
    }
}
