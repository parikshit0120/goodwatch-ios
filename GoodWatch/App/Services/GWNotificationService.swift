import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

// ============================================
// NOTIFICATION SERVICE — ALL TYPES
// ============================================
//
// 1. REMOTE PUSH (via FCM)
//    - Server-triggered (built separately)
//    - Token capture, storage, refresh
//
// 2. LOCAL SCHEDULED
//    - Friday/Saturday evening picks (7:30 PM IST)
//    - Re-engagement after 3 days inactive
//
// 3. RICH NOTIFICATIONS
//    - Movie poster attachment on pick notifications
//    - Expandable with poster image
//
// 4. SILENT BACKGROUND UPDATES
//    - Prefetch next recommendation data
//    - Refresh OTT catalog silently
//
// 5. NOTIFICATION CATEGORIES & ACTIONS
//    - "Show Me" action on pick notifications
//    - "Later" dismiss action
//    - Grouped under "picks" thread
//
// Permission: requested AFTER first recommendation, never during onboarding.
// If declined, never asked again.
// ============================================

final class GWNotificationService: NSObject, ObservableObject {

    static let shared = GWNotificationService()

    // MARK: - Constants

    // UserDefaults keys
    private let kPermissionAsked = "notification_permission_asked"
    private let kPermissionGranted = "notification_permission_granted"
    private let kLastActiveDate = "notification_last_active_date"
    private let kLastMood = "notification_last_user_mood"

    // Notification identifiers
    static let categoryPick = "PICK_READY"
    static let categoryReEngagement = "RE_ENGAGEMENT"
    static let actionShowMe = "SHOW_ME_ACTION"
    static let actionLater = "LATER_ACTION"
    static let threadPicks = "goodwatch-picks"
    static let threadReEngagement = "goodwatch-reengagement"

    // Local notification identifiers
    private let fridayPickId = "friday-evening-pick"
    private let saturdayPickId = "saturday-evening-pick"
    private let reEngagementId = "re-engagement-3day"

    // MARK: - Public State

    /// Whether we've already asked the user for notification permission
    var hasAskedPermission: Bool {
        UserDefaults.standard.bool(forKey: kPermissionAsked)
    }

    /// Whether user granted notification permission
    var isPermissionGranted: Bool {
        UserDefaults.standard.bool(forKey: kPermissionGranted)
    }

    // MARK: - Setup (call once at app launch)

    /// Register notification categories and actions. Call from AppDelegate.
    func registerCategories() {
        // "Show Me" — opens app to recommendation screen
        let showMeAction = UNNotificationAction(
            identifier: Self.actionShowMe,
            title: "Show Me",
            options: [.foreground]
        )

        // "Later" — dismisses notification
        let laterAction = UNNotificationAction(
            identifier: Self.actionLater,
            title: "Later",
            options: [.destructive]
        )

        // Pick ready category (Friday/Saturday evening + server-sent picks)
        let pickCategory = UNNotificationCategory(
            identifier: Self.categoryPick,
            actions: [showMeAction, laterAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Your movie pick is ready",
            options: [.customDismissAction]
        )

        // Re-engagement category (3 days inactive)
        let reEngagementCategory = UNNotificationCategory(
            identifier: Self.categoryReEngagement,
            actions: [showMeAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "New picks waiting",
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            pickCategory,
            reEngagementCategory
        ])
    }

    // ========================================
    // SECTION 1: PERMISSION REQUEST
    // ========================================

    /// Request notification permission. Call ONLY after the user has seen their first recommendation.
    /// If already asked, this is a no-op.
    func requestPermissionIfNeeded() {
        guard !hasAskedPermission else { return }

        // Mark as asked immediately to prevent double-ask
        UserDefaults.standard.set(true, forKey: kPermissionAsked)

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound, .provisional]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: self?.kPermissionGranted ?? "")

                if granted {
                    // Register for remote notifications on main thread
                    UIApplication.shared.registerForRemoteNotifications()
                    // Capture FCM token now that permission is granted
                    self?.captureFCMToken()
                    // Schedule recurring local notifications
                    self?.scheduleWeekendPickNotifications()
                    // Track event
                    MetricsService.shared.track(.pushPermissionGranted)
                    #if DEBUG
                    print("GWNotification: Permission granted, registering for remote notifications")
                    #endif
                } else {
                    // Track event
                    MetricsService.shared.track(.pushPermissionDenied)
                    #if DEBUG
                    print("GWNotification: Permission denied by user")
                    if let error = error {
                        print("GWNotification: Error: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
        }
    }

    // ========================================
    // SECTION 2: FCM TOKEN MANAGEMENT (Remote Push)
    // ========================================

    /// Get current FCM token and store it. Called after permission is granted.
    func captureFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                #if DEBUG
                print("GWNotification: FCM token error: \(error.localizedDescription)")
                #endif
                return
            }

            guard let token = token else {
                #if DEBUG
                print("GWNotification: FCM token is nil")
                #endif
                return
            }

            #if DEBUG
            print("GWNotification: FCM token captured: \(token.prefix(20))...")
            #endif

            self?.storeFCMToken(token)
        }
    }

    /// Handle FCM token refresh (called by AppDelegate when token rotates)
    func handleTokenRefresh(_ token: String) {
        #if DEBUG
        print("GWNotification: FCM token refreshed: \(token.prefix(20))...")
        #endif
        storeFCMToken(token)
    }

    // MARK: - Supabase Token Storage

    /// Cached APNs token (hex string) — set by AppDelegate when APNs registers
    private var pendingAPNsToken: String?

    /// Store raw APNs device token for direct APNs sending. Called from AppDelegate.
    func storeAPNsToken(_ tokenHex: String) {
        pendingAPNsToken = tokenHex

        // If we already have a user, upsert immediately
        guard SupabaseConfig.isConfigured,
              let userId = AuthGuard.shared.currentUserId else { return }

        Task {
            await upsertDeviceToken(userId: userId.uuidString, fcmToken: nil, apnsToken: tokenHex)
        }
    }

    private func storeFCMToken(_ token: String) {
        guard SupabaseConfig.isConfigured else { return }

        guard let userId = AuthGuard.shared.currentUserId else {
            #if DEBUG
            print("GWNotification: No user ID, skipping token storage")
            #endif
            return
        }

        Task {
            await upsertDeviceToken(userId: userId.uuidString, fcmToken: token, apnsToken: pendingAPNsToken)
        }
    }

    private func upsertDeviceToken(userId: String, fcmToken: String?, apnsToken: String?) async {
        let urlString = "\(SupabaseConfig.url)/rest/v1/device_tokens?on_conflict=user_id,platform"
        guard let url = URL(string: urlString) else { return }

        let now = ISO8601DateFormatter().string(from: Date())
        var body: [String: Any] = [
            "user_id": userId,
            "platform": "ios",
            "updated_at": now
        ]
        if let fcmToken = fcmToken {
            body["fcm_token"] = fcmToken
        }
        if let apnsToken = apnsToken {
            body["apns_token"] = apnsToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                #if DEBUG
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("GWNotification: Token stored in Supabase (fcm=\(fcmToken != nil), apns=\(apnsToken != nil))")
                } else {
                    print("GWNotification: Token storage failed with status \(httpResponse.statusCode)")
                }
                #endif
            }
        } catch {
            #if DEBUG
            print("GWNotification: Token storage error: \(error.localizedDescription)")
            #endif
        }
    }

    // ========================================
    // SECTION 3: LOCAL SCHEDULED NOTIFICATIONS
    // ========================================

    /// Save the user's last mood after a recommendation. Used to personalize weekend notifications.
    func saveLastMood(_ mood: String) {
        UserDefaults.standard.set(mood, forKey: kLastMood)
    }

    /// Schedule Friday and Saturday evening pick notifications.
    /// These fire locally at 7:30 PM IST (UTC+5:30) every week.
    /// Reschedules on each app launch to keep them fresh.
    /// Copy is personalized based on the user's last mood.
    func scheduleWeekendPickNotifications() {
        guard isPermissionGranted else { return }

        let center = UNUserNotificationCenter.current()

        // Remove old scheduled picks before rescheduling
        center.removePendingNotificationRequests(withIdentifiers: [fridayPickId, saturdayPickId])

        // Pick notification copy based on last user mood
        let lastMood = UserDefaults.standard.string(forKey: kLastMood) ?? ""
        let (fridayBody, saturdayBody) = weekendCopyForMood(lastMood)

        // IST timezone for scheduling
        let ist = TimeZone(identifier: "Asia/Kolkata")!

        // Friday 7:30 PM IST
        var fridayComponents = DateComponents()
        fridayComponents.weekday = 6 // Friday
        fridayComponents.hour = 19
        fridayComponents.minute = 30
        fridayComponents.timeZone = ist

        let fridayContent = UNMutableNotificationContent()
        fridayContent.title = "Your pick for tonight is ready"
        fridayContent.body = fridayBody
        fridayContent.sound = .default
        fridayContent.categoryIdentifier = Self.categoryPick
        fridayContent.threadIdentifier = Self.threadPicks
        fridayContent.interruptionLevel = .timeSensitive

        let fridayTrigger = UNCalendarNotificationTrigger(dateMatching: fridayComponents, repeats: true)
        let fridayRequest = UNNotificationRequest(identifier: fridayPickId, content: fridayContent, trigger: fridayTrigger)

        // Saturday 7:30 PM IST
        var saturdayComponents = DateComponents()
        saturdayComponents.weekday = 7 // Saturday
        saturdayComponents.hour = 19
        saturdayComponents.minute = 30
        saturdayComponents.timeZone = ist

        let saturdayContent = UNMutableNotificationContent()
        saturdayContent.title = "Your pick for tonight is ready"
        saturdayContent.body = saturdayBody
        saturdayContent.sound = .default
        saturdayContent.categoryIdentifier = Self.categoryPick
        saturdayContent.threadIdentifier = Self.threadPicks
        saturdayContent.interruptionLevel = .timeSensitive

        let saturdayTrigger = UNCalendarNotificationTrigger(dateMatching: saturdayComponents, repeats: true)
        let saturdayRequest = UNNotificationRequest(identifier: saturdayPickId, content: saturdayContent, trigger: saturdayTrigger)

        center.add(fridayRequest) { error in
            #if DEBUG
            if let error = error {
                print("GWNotification: Failed to schedule Friday pick: \(error)")
            } else {
                print("GWNotification: Friday 7:30 PM IST pick scheduled (mood: \(lastMood))")
            }
            #endif
        }

        center.add(saturdayRequest) { error in
            #if DEBUG
            if let error = error {
                print("GWNotification: Failed to schedule Saturday pick: \(error)")
            } else {
                print("GWNotification: Saturday 7:30 PM IST pick scheduled (mood: \(lastMood))")
            }
            #endif
        }
    }

    /// Returns (fridayBody, saturdayBody) personalized to the user's last mood
    private func weekendCopyForMood(_ mood: String) -> (String, String) {
        switch mood.lowercased() {
        case "feel_good", "feelgood":
            return (
                "Something warm and uplifting tonight. One tap.",
                "Weekend feel-good pick ready. You'll love this one."
            )
        case "intense", "gripping":
            return (
                "Something gripping lined up for tonight. One tap.",
                "Weekend intensity. We found the perfect edge-of-seat pick."
            )
        case "light", "casual":
            return (
                "Light and easy for tonight. One tap.",
                "Weekend chill pick ready. No thinking required."
            )
        case "curious", "thoughtful":
            return (
                "Something thought-provoking for tonight. One tap.",
                "Weekend deep-dive pick ready. Feed your curiosity."
            )
        default:
            return (
                "We found something you'll love. One tap.",
                "Weekend vibes. We've got the perfect match."
            )
        }
    }

    /// Schedule a re-engagement notification 3 days from now.
    /// Called when user opens the app — resets the timer each time.
    func scheduleReEngagementNotification() {
        guard isPermissionGranted else { return }

        let center = UNUserNotificationCenter.current()

        // Remove previous re-engagement notification (resets the 3-day timer)
        center.removePendingNotificationRequests(withIdentifiers: [reEngagementId])

        let content = UNMutableNotificationContent()
        content.title = "We missed you"
        content.body = "New picks waiting based on your mood."
        content.sound = .default
        content.categoryIdentifier = Self.categoryReEngagement
        content.threadIdentifier = Self.threadReEngagement

        // 3 days = 259200 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 259200, repeats: false)
        let request = UNNotificationRequest(identifier: reEngagementId, content: content, trigger: trigger)

        center.add(request) { error in
            #if DEBUG
            if let error = error {
                print("GWNotification: Failed to schedule re-engagement: \(error)")
            } else {
                print("GWNotification: Re-engagement notification scheduled (3 days)")
            }
            #endif
        }
    }

    // ========================================
    // SECTION 4: RICH NOTIFICATIONS (poster attachment)
    // ========================================

    /// Schedule a local notification with a movie poster image attachment.
    /// Used when the app pre-fetches a recommendation and wants to notify with rich media.
    func scheduleRichPickNotification(title: String, posterURL: URL, movieTitle: String, delay: TimeInterval = 1) {
        guard isPermissionGranted else { return }

        // Download poster to temp file for attachment
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: posterURL)

                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "poster_\(UUID().uuidString).jpg"
                let fileURL = tempDir.appendingPathComponent(fileName)
                try data.write(to: fileURL)

                let attachment = try UNNotificationAttachment(
                    identifier: "poster",
                    url: fileURL,
                    options: [
                        UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg",
                        UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                            CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation
                    ]
                )

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = movieTitle
                content.sound = .default
                content.categoryIdentifier = Self.categoryPick
                content.threadIdentifier = Self.threadPicks
                content.attachments = [attachment]
                content.interruptionLevel = .timeSensitive

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "rich-pick-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    #if DEBUG
                    if let error = error {
                        print("GWNotification: Rich notification failed: \(error)")
                    } else {
                        print("GWNotification: Rich notification scheduled for '\(movieTitle)'")
                    }
                    #endif
                }

                // Clean up temp file after a delay (iOS copies it for the notification)
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                    try? FileManager.default.removeItem(at: fileURL)
                }

            } catch {
                #if DEBUG
                print("GWNotification: Failed to create rich notification: \(error)")
                #endif
            }
        }
    }

    // ========================================
    // SECTION 5: SILENT BACKGROUND UPDATES
    // ========================================

    /// Handle silent push notification (content-available: 1).
    /// Called from AppDelegate when a silent push arrives.
    /// Use for prefetching recommendation data or refreshing OTT catalog.
    func handleSilentPush(userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let action = userInfo["silent_action"] as? String else {
            completion(.noData)
            return
        }

        switch action {
        case "prefetch_recommendation":
            // Future: prefetch next recommendation so it's instant when user opens app
            #if DEBUG
            print("GWNotification: Silent push — prefetch recommendation")
            #endif
            completion(.newData)

        case "refresh_catalog":
            // Future: refresh OTT catalog data
            #if DEBUG
            print("GWNotification: Silent push — refresh catalog")
            #endif
            completion(.newData)

        default:
            #if DEBUG
            print("GWNotification: Unknown silent action: \(action)")
            #endif
            completion(.noData)
        }
    }

    // ========================================
    // SECTION 6: ACTIVITY TRACKING
    // ========================================

    /// Call when user opens the app or takes any action.
    /// Resets the re-engagement notification timer.
    func trackUserActive() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kLastActiveDate)

        // Reset re-engagement timer every time user is active
        scheduleReEngagementNotification()
    }

    /// Clear badge count
    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    // ========================================
    // SECTION 7: NOTIFICATION MANAGEMENT
    // ========================================

    /// Remove all delivered notifications (call when user opens the app)
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        clearBadge()
    }

    /// Cancel all pending local notifications
    func cancelAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Debug: list all pending notifications
    #if DEBUG
    func debugListPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("GWNotification: \(requests.count) pending notifications:")
            for req in requests {
                print("  - \(req.identifier): \(req.content.title) | trigger: \(String(describing: req.trigger))")
            }
        }
    }
    #endif
}

// MARK: - Foreground & Tap Handling

extension GWNotificationService: UNUserNotificationCenterDelegate {

    /// Show notification as in-app banner when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap — route based on category
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        #if DEBUG
        print("GWNotification: Tapped — category: \(categoryId), action: \(actionId)")
        #endif

        // Check if this is an app_update push — open App Store directly
        if let pushType = userInfo["type"] as? String, pushType == "app_update" {
            MetricsService.shared.track(.pushTapped, properties: [
                "category": categoryId,
                "action": "app_update"
            ])
            if let urlString = userInfo["store_url"] as? String,
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
            completionHandler()
            return
        }

        switch actionId {
        case Self.actionShowMe:
            // User tapped "Show Me" — post notification to navigate to recommendation
            MetricsService.shared.track(.pushTapped, properties: [
                "category": categoryId,
                "action": "show_me"
            ])
            NotificationCenter.default.post(
                name: .gwNavigateToRecommendation,
                object: nil,
                userInfo: userInfo
            )

        case UNNotificationDefaultActionIdentifier:
            // Default tap (not an action button) — same as Show Me
            MetricsService.shared.track(.pushTapped, properties: [
                "category": categoryId,
                "action": "default_tap"
            ])
            NotificationCenter.default.post(
                name: .gwNavigateToRecommendation,
                object: nil,
                userInfo: userInfo
            )

        case Self.actionLater, UNNotificationDismissActionIdentifier:
            // Dismissed — no action needed
            break

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Navigation Notification Name

extension Notification.Name {
    /// Posted when a notification tap should navigate to the recommendation screen
    static let gwNavigateToRecommendation = Notification.Name("gwNavigateToRecommendation")
}
