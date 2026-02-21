import Foundation

enum OTTPlatform: String, CaseIterable, Codable {
    case jioHotstar = "jio_hotstar"
    case prime = "prime"
    case netflix = "netflix"
    case sonyLIV = "sony_liv"
    case zee5 = "zee5"
    case appleTV = "apple_tv"

    var displayName: String {
        switch self {
        case .jioHotstar: return "Jio Hotstar"
        case .prime: return "Prime Video"
        case .netflix: return "Netflix"
        case .sonyLIV: return "Sony LIV"
        case .zee5: return "ZEE5"
        case .appleTV: return "Apple TV+"
        }
    }
}

enum Mood: String, CaseIterable, Codable {
    case neutral
    case light
    case intense
    case feelGood
}

enum Language: String, CaseIterable, Codable {
    case english = "english"
    case hindi = "hindi"
    case tamil = "tamil"
    case telugu = "telugu"
    case malayalam = "malayalam"
    case kannada = "kannada"
    case bengali = "bengali"
    case marathi = "marathi"
    case punjabi = "punjabi"
    case gujarati = "gujarati"
    case korean = "korean"
    case japanese = "japanese"
    case spanish = "spanish"
    case french = "french"
    case chinese = "chinese"
    case portuguese = "portuguese"

    /// Languages shown in the onboarding UI — sorted by catalog size
    static var visibleCases: [Language] {
        [.english, .hindi, .tamil, .telugu, .malayalam, .korean,
         .kannada, .bengali, .marathi, .spanish, .japanese, .french,
         .punjabi, .chinese, .portuguese, .gujarati]
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "Hindi"
        case .tamil: return "Tamil"
        case .telugu: return "Telugu"
        case .malayalam: return "Malayalam"
        case .kannada: return "Kannada"
        case .bengali: return "Bengali"
        case .marathi: return "Marathi"
        case .punjabi: return "Punjabi"
        case .gujarati: return "Gujarati"
        case .korean: return "Korean"
        case .japanese: return "Japanese"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .chinese: return "Chinese"
        case .portuguese: return "Portuguese"
        }
    }

    /// ISO 639-1 code for database queries
    var isoCode: String {
        switch self {
        case .english: return "en"
        case .hindi: return "hi"
        case .tamil: return "ta"
        case .telugu: return "te"
        case .malayalam: return "ml"
        case .kannada: return "kn"
        case .bengali: return "bn"
        case .marathi: return "mr"
        case .punjabi: return "pa"
        case .gujarati: return "gu"
        case .korean: return "ko"
        case .japanese: return "ja"
        case .spanish: return "es"
        case .french: return "fr"
        case .chinese: return "zh"
        case .portuguese: return "pt"
        }
    }
}

struct UserContext: Codable {
    var otts: [OTTPlatform]
    var mood: Mood
    var maxDuration: Int
    var minDuration: Int
    var languages: [Language]
    var intent: GWIntent
    var requiresSeries: Bool  // True when "Series/Binge" is selected

    static let `default` = UserContext(
        otts: [],
        mood: .neutral,
        maxDuration: 180,
        minDuration: 60,
        languages: [],
        intent: .default,
        requiresSeries: false
    )

    // Convert to GWValidationProfile for validation
    func toProfile(id: String = "anonymous") -> GWValidationProfile {
        GWValidationProfile(
            id: id,
            preferred_languages: languages.map { $0.rawValue },
            platforms: otts.map { $0.rawValue },
            runtime_window: (minDuration, maxDuration),
            risk_tolerance: .medium
        )
    }

    // MARK: - Onboarding Persistence

    private static let storageKey = "gw_onboarding_context"

    func saveToDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func loadFromDefaults() -> UserContext? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(UserContext.self, from: data)
    }

    static func clearDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
