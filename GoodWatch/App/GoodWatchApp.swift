import SwiftUI
import GoogleSignIn
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// Firebase initialization via AppDelegate + Push Notification handling
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Set up FCM delegate for token refresh
        Messaging.messaging().delegate = self

        // Set up notification center delegate for foreground + tap handling
        UNUserNotificationCenter.current().delegate = GWNotificationService.shared

        // Register notification categories and actions (Show Me / Later buttons)
        GWNotificationService.shared.registerCategories()

        return true
    }

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass APNs token to Firebase so it can map to FCM token
        Messaging.messaging().apnsToken = deviceToken

        // Also store the raw APNs token for direct APNs sending
        let tokenHex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        GWNotificationService.shared.storeAPNsToken(tokenHex)

        #if DEBUG
        print("GWNotification: APNs token registered: \(tokenHex.prefix(20))...")
        #endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("GWNotification: APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Silent Push / Background Fetch

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle silent push notifications (content-available: 1)
        GWNotificationService.shared.handleSilentPush(userInfo: userInfo, completion: completionHandler)
    }

    // MARK: - FCM Token Refresh

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        GWNotificationService.shared.handleTokenRefresh(token)
    }
}

@main
struct GoodWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback URL
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    #if DEBUG
                    await runDataDiagnostic()
                    #endif
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        // Clear delivered notifications and badge when user opens the app
                        GWNotificationService.shared.clearDeliveredNotifications()
                        // Reset the 3-day re-engagement timer
                        GWNotificationService.shared.trackUserActive()
                        // Reschedule weekend picks (keeps them fresh for existing users)
                        GWNotificationService.shared.scheduleWeekendPickNotifications()
                        // Track session start
                        MetricsService.shared.track(.sessionStart)
                    case .background:
                        MetricsService.shared.track(.sessionEnd)
                        MetricsService.shared.onAppBackground()
                        GWFeedbackEnforcer.shared.cleanupOldFeedback()
                    default:
                        break
                    }
                }
        }
    }

    init() {
        // Track app open on launch
        MetricsService.shared.track(.appOpen)

        #if DEBUG
        // Launch argument overrides for screenshot testing
        let args = ProcessInfo.processInfo.arguments

        // --screenshot-mode: Suppress analytics and diagnostics
        if args.contains("--screenshot-mode") {
            UserDefaults.standard.set(true, forKey: "gw_screenshot_mode")
        }

        // --interaction-points N: Override interaction points for carousel testing
        if let idx = args.firstIndex(of: "--interaction-points"),
           idx + 1 < args.count,
           let points = Int(args[idx + 1]) {
            // Set interaction points for all users (applied when setUser is called)
            UserDefaults.standard.set(points, forKey: "gw_debug_interaction_points")
        }

        // --skip-loading-delay: Skip ConfidenceMoment animation delay
        if args.contains("--skip-loading-delay") {
            UserDefaults.standard.set(true, forKey: "gw_skip_loading_delay")
        }

        // --reset-onboarding: Clear all onboarding state for fresh screenshots
        if args.contains("--reset-onboarding") {
            GWKeychainManager.shared.storeOnboardingStep(0)
            GWOnboardingMemory.shared.clear()
            UserContext.clearDefaults()
            UserDefaults.standard.removeObject(forKey: "notification_permission_asked")
            // Clear cached user ID so auth screen appears
            UserDefaults.standard.removeObject(forKey: "gw_user_id")
            // Clear ALL interaction points and ratchet data for all users
            let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
            for key in allKeys {
                if key.hasPrefix("gw_interaction_points_") || key.hasPrefix("gw_max_pick_tier_reached_") {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        // --force-feature-flag <name>: Force a feature flag to enabled
        if let idx = args.firstIndex(of: "--force-feature-flag"),
           idx + 1 < args.count {
            let flagName = args[idx + 1]
            UserDefaults.standard.set(true, forKey: "gw_forced_flag_\(flagName)")
        }
        #endif
    }

    // MARK: - DEBUG Data Diagnostic

    #if DEBUG
    /// One-time data quality check on launch.
    /// Fetches a sample of movies and prints content_type distribution,
    /// emotional_profile coverage, platform coverage, and quality gate pass rates.
    private func runDataDiagnostic() async {
        print("\n🔍 ═══════════════════════════════════════")
        print("🔍 DATA DIAGNOSTIC — GoodWatch DB Health")
        print("🔍 ═══════════════════════════════════════\n")

        do {
            let movies = try await SupabaseService.shared.fetchMovies(limit: 500)
            print("📦 Fetched \(movies.count) movies for diagnostic\n")

            // 1. Content type distribution
            let contentTypes = Dictionary(grouping: movies, by: { $0.content_type ?? "NULL" })
            print("📊 CONTENT TYPE DISTRIBUTION:")
            for (ct, list) in contentTypes.sorted(by: { $0.value.count > $1.value.count }) {
                print("   \(ct): \(list.count) (\(pct(list.count, movies.count)))")
            }

            // 2. Emotional profile coverage
            let hasEmotional = movies.filter { $0.emotional_profile != nil }.count
            let noEmotional = movies.count - hasEmotional
            print("\n🧠 EMOTIONAL PROFILE:")
            print("   Has profile: \(hasEmotional) (\(pct(hasEmotional, movies.count)))")
            print("   Missing: \(noEmotional) (\(pct(noEmotional, movies.count)))")

            // 3. Rating coverage
            let hasComposite = movies.filter { ($0.composite_score ?? 0) > 0 }.count
            let hasIMDb = movies.filter { $0.imdb_rating != nil }.count
            let hasTMDb = movies.filter { $0.vote_average != nil }.count
            let noRating = movies.filter { ($0.composite_score ?? 0) == 0 && $0.imdb_rating == nil && $0.vote_average == nil }.count
            print("\n⭐ RATING COVERAGE:")
            print("   Composite score: \(hasComposite) (\(pct(hasComposite, movies.count)))")
            print("   IMDb rating: \(hasIMDb) (\(pct(hasIMDb, movies.count)))")
            print("   TMDb rating: \(hasTMDb) (\(pct(hasTMDb, movies.count)))")
            print("   No rating at all: \(noRating) (\(pct(noRating, movies.count)))")

            // 4. OTT provider coverage
            let hasProviders = movies.filter { !($0.ott_providers ?? []).isEmpty }.count
            let hasSupportedProviders = movies.filter { !$0.supportedProviders.isEmpty }.count
            print("\n📺 OTT PROVIDER COVERAGE:")
            print("   Has any providers: \(hasProviders) (\(pct(hasProviders, movies.count)))")
            print("   Has supported providers (6 apps): \(hasSupportedProviders) (\(pct(hasSupportedProviders, movies.count)))")

            // Count per-platform coverage
            var platformCounts: [String: Int] = [:]
            for movie in movies {
                for provider in movie.supportedProviders {
                    let name = provider.displayName
                    platformCounts[name, default: 0] += 1
                }
            }
            for (name, count) in platformCounts.sorted(by: { $0.value > $1.value }) {
                print("     \(name): \(count)")
            }

            // 5. Unsupported providers appearing (what are we hiding?)
            var unsupportedNames: [String: Int] = [:]
            for movie in movies {
                for provider in (movie.ott_providers ?? []) {
                    if !Movie.isSupportedProvider(provider.name) {
                        unsupportedNames[provider.name, default: 0] += 1
                    }
                }
            }
            if !unsupportedNames.isEmpty {
                print("\n⚠️  UNSUPPORTED PROVIDERS (hidden from users):")
                for (name, count) in unsupportedNames.sorted(by: { $0.value > $1.value }).prefix(10) {
                    print("     \(name): \(count)")
                }
            }

            // 6. Tag derivation coverage
            let engine = GWRecommendationEngine.shared
            var hasTags = 0
            var noTags = 0
            for movie in movies {
                let gwMovie = GWMovie(from: movie)
                if gwMovie.tags.isEmpty {
                    noTags += 1
                } else {
                    hasTags += 1
                }
            }
            print("\n🏷️  TAG DERIVATION:")
            print("   Has tags: \(hasTags) (\(pct(hasTags, movies.count)))")
            print("   No tags (engine can't score): \(noTags) (\(pct(noTags, movies.count)))")

            // 7. Runtime distribution
            let runtimes = movies.compactMap { $0.runtime }
            if !runtimes.isEmpty {
                let avg = runtimes.reduce(0, +) / runtimes.count
                let below60 = runtimes.filter { $0 < 60 }.count
                let above180 = runtimes.filter { $0 > 180 }.count
                print("\n⏱️  RUNTIME:")
                print("   Has runtime: \(runtimes.count) (\(pct(runtimes.count, movies.count)))")
                print("   Average: \(avg) min")
                print("   Under 60 min: \(below60), Over 180 min: \(above180)")
            }

            // 8. Quality gate: would pass engine validation?
            let defaultProfile = GWUserProfileComplete(
                userId: "diagnostic",
                preferredLanguages: ["english"],
                platforms: ["netflix", "prime"],
                runtimeWindow: GWRuntimeWindow(min: 60, max: 180),
                mood: "neutral",
                intentTags: ["safe_bet", "feel_good"],
                seen: [],
                notTonight: [],
                abandoned: [],
                recommendationStyle: .safe,
                tagWeights: [:]
            )
            var passCount = 0
            var failReasons: [String: Int] = [:]
            for movie in movies.prefix(200) {
                let gwMovie = GWMovie(from: movie)
                let result = engine.isValidMovie(gwMovie, profile: defaultProfile)
                switch result {
                case .valid:
                    passCount += 1
                case .invalid(let reason):
                    // Extract failure type name from the description (e.g. "LANGUAGE_MISMATCH: ...")
                    let label = reason.description.components(separatedBy: ":").first ?? "unknown"
                    failReasons[label, default: 0] += 1
                }
            }
            let checked = min(200, movies.count)
            print("\n✅ VALIDATION GATE (first \(checked) movies, English + Netflix/Prime + 60-180m):")
            print("   Pass: \(passCount) (\(pct(passCount, checked)))")
            for (reason, count) in failReasons.sorted(by: { $0.value > $1.value }) {
                print("   ❌ \(reason): \(count)")
            }

            print("\n🔍 ═══════════════════════════════════════")
            print("🔍 DIAGNOSTIC COMPLETE")
            print("🔍 ═══════════════════════════════════════\n")

        } catch {
            print("❌ Data diagnostic failed: \(error)")
        }
    }

    private func pct(_ num: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(num) / Double(total) * 100)
    }
    #endif
}
