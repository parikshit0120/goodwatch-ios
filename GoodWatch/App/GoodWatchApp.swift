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
        }
    }

    init() {
        // Track app open on launch
        MetricsService.shared.track(.appOpen)
    }
}
