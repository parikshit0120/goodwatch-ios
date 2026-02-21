import Foundation

/// Lightweight remote feature flag service.
/// Fetches flags from Supabase on launch, caches in memory,
/// falls back to hardcoded defaults on failure.
final class GWFeatureFlags {
    static let shared = GWFeatureFlags()
    private init() {}

    private var flags: [String: FeatureFlag] = [:]
    private var loaded = false

    struct FeatureFlag: Codable {
        let flag_key: String
        let enabled: Bool
        let payload: [String: JSONValue]?
    }

    // MARK: - Hardcoded Defaults (used if Supabase fetch fails)
    private let defaults: [String: Bool] = [
        "progressive_picks": true,
        "feedback_v2": true,
        "push_notifications": true,
        "remote_mood_mapping": true,
        "taste_engine": true,
        "card_rejection": true,
        "implicit_skip_tracking": true,
        "new_user_recency_gate": true,
    ]

    /// Check if a feature is enabled.
    /// Returns hardcoded default if remote flags haven't loaded.
    func isEnabled(_ key: String) -> Bool {
        if let flag = flags[key] {
            return flag.enabled
        }
        return defaults[key] ?? false
    }

    /// Get the payload for a flag (e.g., config values like max_weight).
    /// Returns nil if flag not found or no payload.
    func payload(for key: String) -> [String: JSONValue]? {
        return flags[key]?.payload
    }

    /// Fetch flags from Supabase. Called on app launch.
    /// Timeout: 3 seconds. On failure, uses hardcoded defaults silently.
    func fetchFlags() async {
        guard SupabaseConfig.isConfigured else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/feature_flags?select=flag_key,enabled,payload"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                #if DEBUG
                print("[FeatureFlags] HTTP error, using defaults")
                #endif
                return
            }

            let decoded = try JSONDecoder().decode([FeatureFlag].self, from: data)
            for flag in decoded {
                flags[flag.flag_key] = flag
            }
            loaded = true

            #if DEBUG
            print("[FeatureFlags] Loaded \(decoded.count) flags from remote")
            for flag in decoded {
                print("  \(flag.flag_key): \(flag.enabled)")
            }
            #endif
        } catch {
            #if DEBUG
            print("[FeatureFlags] Fetch failed: \(error.localizedDescription), using defaults")
            #endif
        }
    }
}

// MARK: - JSONValue (lightweight JSON representation for payload parsing)

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .number(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .number(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }
}
