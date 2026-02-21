import Foundation

// ============================================
// UPDATE CHECKER SERVICE
// ============================================
// Checks the App Store for a newer version on launch.
// Compares major.minor only (ignores patch) so that
// critical releases trigger a banner while small fixes don't.
//
// Flow:
//   1. On app launch, call checkForUpdate()
//   2. Hits iTunes Lookup API with the app's bundle ID
//   3. Parses trackId + version from response
//   4. Compares major.minor against current version
//   5. If newer, sets updateAvailable = true + storeURL
//
// Non-blocking: runs in background, never stalls UI.
// Rate-limited: skips check if last check was < 6 hours ago.
// ============================================

@MainActor
final class GWUpdateChecker: ObservableObject {

    static let shared = GWUpdateChecker()
    private init() {}

    // MARK: - Published State

    @Published var updateAvailable: Bool = false
    @Published var storeURL: URL?
    @Published var latestVersion: String?

    // MARK: - Constants

    /// App bundle ID used for iTunes Lookup
    private let bundleId = "PJWorks.goodwatch.movies.v1"

    /// Minimum hours between checks
    private let checkIntervalHours: Double = 6

    /// UserDefaults keys
    private let kLastCheckDate = "gw_update_check_last_date"
    private let kDismissedVersion = "gw_update_dismissed_version"

    // MARK: - Public API

    /// Check App Store for a newer version. Non-blocking, rate-limited.
    func checkForUpdate() {
        // Rate limit: skip if checked recently
        let lastCheck = UserDefaults.standard.double(forKey: kLastCheckDate)
        let hoursSinceLastCheck = (Date().timeIntervalSince1970 - lastCheck) / 3600
        if lastCheck > 0 && hoursSinceLastCheck < checkIntervalHours {
            #if DEBUG
            print("[UpdateChecker] Skipping — last check was \(String(format: "%.1f", hoursSinceLastCheck))h ago")
            #endif
            return
        }

        Task {
            await performCheck()
        }
    }

    /// User dismissed the update banner — don't show again for this version
    func dismissUpdate() {
        if let version = latestVersion {
            UserDefaults.standard.set(version, forKey: kDismissedVersion)
        }
        updateAvailable = false
    }

    // MARK: - Private

    private func performCheck() async {
        // Mark check time immediately
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kLastCheckDate)

        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=in"
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("[UpdateChecker] Invalid URL")
            #endif
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("[UpdateChecker] HTTP error")
                #endif
                return
            }

            let result = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)

            guard let appInfo = result.results.first else {
                #if DEBUG
                print("[UpdateChecker] No results — app may not be on App Store yet")
                #endif
                return
            }

            let storeVersion = appInfo.version
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"

            #if DEBUG
            print("[UpdateChecker] Store version: \(storeVersion), Current version: \(currentVersion)")
            #endif

            // Compare major.minor only
            let storeMajorMinor = majorMinor(storeVersion)
            let currentMajorMinor = majorMinor(currentVersion)

            if storeMajorMinor > currentMajorMinor {
                // Check if user already dismissed this version
                let dismissed = UserDefaults.standard.string(forKey: kDismissedVersion)
                if dismissed == storeVersion {
                    #if DEBUG
                    print("[UpdateChecker] User dismissed version \(storeVersion)")
                    #endif
                    return
                }

                self.latestVersion = storeVersion
                self.storeURL = URL(string: "https://apps.apple.com/app/id\(appInfo.trackId)")
                self.updateAvailable = true

                #if DEBUG
                print("[UpdateChecker] Update available: \(storeVersion) > \(currentVersion)")
                #endif
            } else {
                #if DEBUG
                print("[UpdateChecker] App is up to date")
                #endif
            }

        } catch {
            #if DEBUG
            print("[UpdateChecker] Check failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Extract (major, minor) tuple from version string for comparison
    private func majorMinor(_ version: String) -> (Int, Int) {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        let major = parts.count > 0 ? parts[0] : 0
        let minor = parts.count > 1 ? parts[1] : 0
        return (major, minor)
    }
}

// MARK: - iTunes Lookup Response

private struct ITunesLookupResponse: Codable {
    let resultCount: Int
    let results: [ITunesAppInfo]
}

private struct ITunesAppInfo: Codable {
    let trackId: Int
    let version: String
    let trackName: String?
}
