import Foundation
import FirebaseRemoteConfig

/// Singleton wrapper around Firebase Remote Config.
/// Provides server-controlled values for feature flags and limits.
///
/// Defaults are compiled in; Remote Config values override on fetch.
/// Call `fetchAndActivate()` once on app launch (from AppDelegate).
final class GWRemoteConfig {
    static let shared = GWRemoteConfig()

    private let remoteConfig = RemoteConfig.remoteConfig()

    // MARK: - Config Keys

    private enum Key: String {
        case freeLimit = "free_daily_limit"
        case forceUpdate = "force_update_min_version"
        case maintenanceMode = "maintenance_mode"
        case maxPicksPerSession = "max_picks_per_session"
    }

    // MARK: - Init

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0   // No throttle in debug
        #else
        settings.minimumFetchInterval = 3600  // 1 hour in production
        #endif
        remoteConfig.configSettings = settings

        // In-app defaults (used until first successful fetch)
        remoteConfig.setDefaults([
            Key.freeLimit.rawValue: NSNumber(value: 3),
            Key.forceUpdate.rawValue: "0.0" as NSString,
            Key.maintenanceMode.rawValue: false as NSNumber,
            Key.maxPicksPerSession.rawValue: NSNumber(value: 50)
        ])
    }

    // MARK: - Fetch

    /// Fetch and activate remote values. Call once on app launch.
    func fetchAndActivate() {
        remoteConfig.fetchAndActivate { status, error in
            #if DEBUG
            switch status {
            case .successFetchedFromRemote:
                print("[GWRemoteConfig] Fetched from remote")
            case .successUsingPreFetchedData:
                print("[GWRemoteConfig] Using pre-fetched data")
            case .error:
                print("[GWRemoteConfig] Fetch error: \(error?.localizedDescription ?? "unknown")")
            @unknown default:
                break
            }
            #endif
        }
    }

    // MARK: - Accessors

    /// Daily free recommendation limit (default: 3).
    var freeLimit: Int {
        return remoteConfig[Key.freeLimit.rawValue].numberValue.intValue
    }

    /// Minimum app version required (for force-update prompts).
    var forceUpdateMinVersion: String {
        return remoteConfig[Key.forceUpdate.rawValue].stringValue ?? "0.0"
    }

    /// Whether the app is in maintenance mode.
    var maintenanceMode: Bool {
        return remoteConfig[Key.maintenanceMode.rawValue].boolValue
    }

    /// Maximum picks allowed per session (default: 50).
    var maxPicksPerSession: Int {
        return remoteConfig[Key.maxPicksPerSession.rawValue].numberValue.intValue
    }
}
