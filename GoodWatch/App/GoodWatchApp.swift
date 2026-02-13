import SwiftUI
import GoogleSignIn
import FirebaseCore

// Firebase initialization via AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
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
        }
    }

    init() {
        // Track app open on launch
        MetricsService.shared.track(.appOpen)
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
