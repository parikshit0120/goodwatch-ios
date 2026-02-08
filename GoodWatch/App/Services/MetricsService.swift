//
//  MetricsService.swift
//  GoodWatch
//
//  Dual logging: Firebase Analytics + Supabase app_events table.
//  Events buffer in-memory and flush to Supabase on background/threshold.
//  Firebase events fire immediately (Firebase handles its own batching).
//

import Foundation
import FirebaseAnalytics

// MARK: - Event Types

enum MetricEvent: String {
    // Core recommendation flow
    case appOpen = "app_open"
    case pickShown = "pick_shown"
    case watchNow = "watch_now"
    case sessionReset = "session_reset"
    case retrySoft = "retry_soft"
    case rejectHard = "reject_hard"
    case availabilityFiltered = "availability_filtered_out"

    // Onboarding
    case onboardingStart = "onboarding_start"
    case onboardingComplete = "onboarding_complete"

    // Auth
    case signIn = "sign_in"

    // Engagement
    case firstRecommendation = "first_recommendation"
    case feedbackGiven = "feedback_given"
}

// MARK: - Log Entry

struct LogEntry {
    let timestamp: Date
    let event: MetricEvent
    let properties: [String: Any]
}

// MARK: - Supabase Event Payload (for batch upload)

private struct SupabaseEvent: Encodable {
    let user_id: String?
    let device_id: String?
    let event_name: String
    let properties: [String: String] // Simplified to string values for JSON encoding
    let session_id: String
    let created_at: String
}

// MARK: - Metrics Service

class MetricsService {
    static let shared = MetricsService()

    private var sessionLogs: [LogEntry] = []
    private var supabaseBuffer: [LogEntry] = []
    private let sessionId = UUID().uuidString
    private let bufferFlushThreshold = 20
    private let queue = DispatchQueue(label: "com.goodwatch.metrics", qos: .utility)

    // User context (set after auth)
    private(set) var userId: String?
    private(set) var deviceId: String?

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    private init() {
        // Generate a stable device ID for anonymous tracking
        if let stored = UserDefaults.standard.string(forKey: "gw_device_id") {
            deviceId = stored
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "gw_device_id")
            deviceId = newId
        }
    }

    // MARK: - Set User Context

    /// Call after authentication to associate events with a user
    func setUser(id: String, authType: String) {
        self.userId = id

        // Set Firebase user properties
        Analytics.setUserID(id)
        Analytics.setUserProperty(authType, forName: "auth_type")
    }

    /// Set user preferences as Firebase user properties
    func setUserProperties(platformsCount: Int, preferredLanguage: String) {
        Analytics.setUserProperty(String(platformsCount), forName: "platforms_count")
        Analytics.setUserProperty(preferredLanguage, forName: "preferred_language")
    }

    // MARK: - Track Event

    func track(_ event: MetricEvent, properties: [String: Any] = [:]) {
        let entry = LogEntry(timestamp: Date(), event: event, properties: properties)

        // 1. Local session log (always)
        sessionLogs.append(entry)

        // 2. Firebase Analytics (immediate — Firebase handles its own batching)
        logToFirebase(event: event, properties: properties)

        // 3. Buffer for Supabase (batch upload)
        queue.async { [weak self] in
            self?.supabaseBuffer.append(entry)
            if let count = self?.supabaseBuffer.count, count >= self?.bufferFlushThreshold ?? 20 {
                self?.flushToSupabase()
            }
        }

        #if DEBUG
        print("📊 [METRIC] \(event.rawValue)\(properties.isEmpty ? "" : " | \(properties)")")
        #endif
    }

    // MARK: - Firebase Logging

    private func logToFirebase(event: MetricEvent, properties: [String: Any]) {
        // Convert properties to Firebase-compatible format
        var firebaseParams: [String: Any] = [:]

        for (key, value) in properties {
            if let str = value as? String {
                firebaseParams[key] = str
            } else if let num = value as? NSNumber {
                firebaseParams[key] = num
            } else if let bool = value as? Bool {
                firebaseParams[key] = bool ? "true" : "false"
            } else {
                firebaseParams[key] = String(describing: value)
            }
        }

        Analytics.logEvent(event.rawValue, parameters: firebaseParams.isEmpty ? nil : firebaseParams)
    }

    // MARK: - Supabase Batch Upload

    /// Flush buffered events to Supabase. Called on app background, threshold, or session end.
    func flushToSupabase() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.supabaseBuffer.isEmpty else { return }

            let eventsToSend = self.supabaseBuffer
            self.supabaseBuffer.removeAll()

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let payload: [[String: Any]] = eventsToSend.map { entry in
                // Convert properties to [String: String] for JSON
                var propsDict: [String: String] = [:]
                for (key, value) in entry.properties {
                    propsDict[key] = String(describing: value)
                }

                var dict: [String: Any] = [
                    "event_name": entry.event.rawValue,
                    "properties": propsDict,
                    "session_id": self.sessionId,
                    "created_at": isoFormatter.string(from: entry.timestamp)
                ]

                if let uid = self.userId {
                    dict["user_id"] = uid
                }
                if let did = self.deviceId {
                    dict["device_id"] = did
                }

                return dict
            }

            // POST to Supabase REST API
            let urlString = "\(self.baseURL)/rest/v1/app_events"
            guard let url = URL(string: urlString) else {
                #if DEBUG
                print("❌ [METRIC] Invalid Supabase URL")
                #endif
                // Put events back in buffer on failure
                self.supabaseBuffer.insert(contentsOf: eventsToSend, at: 0)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(self.anonKey)", forHTTPHeaderField: "Authorization")
            // Return minimal response
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                #if DEBUG
                print("❌ [METRIC] JSON serialization failed: \(error)")
                #endif
                self.supabaseBuffer.insert(contentsOf: eventsToSend, at: 0)
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    #if DEBUG
                    print("❌ [METRIC] Supabase upload failed: \(error.localizedDescription)")
                    #endif
                    // Re-buffer on network failure
                    self.queue.async {
                        self.supabaseBuffer.insert(contentsOf: eventsToSend, at: 0)
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else { return }

                #if DEBUG
                if httpResponse.statusCode == 201 {
                    print("✅ [METRIC] Flushed \(eventsToSend.count) events to Supabase")
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                    print("❌ [METRIC] Supabase returned \(httpResponse.statusCode): \(body)")
                }
                #endif
            }.resume()
        }
    }

    // MARK: - App Lifecycle

    /// Call when app goes to background
    func onAppBackground() {
        flushToSupabase()
    }

    // MARK: - Session Summary

    func printSessionSummary() {
        #if DEBUG
        print("\n--- 📝 SESSION LOG SUMMARY ---")
        if sessionLogs.isEmpty {
            print("(No events recorded)")
        } else {
            let formatter = ISO8601DateFormatter()
            for log in sessionLogs {
                let timeStr = formatter.string(from: log.timestamp)
                print("[\(timeStr)] \(log.event.rawValue) \t \(log.properties)")
            }
            print("Total events: \(sessionLogs.count)")
        }
        print("------------------------------\n")
        #endif

        // Flush remaining events to Supabase
        flushToSupabase()
    }

    func clearLogs() {
        sessionLogs.removeAll()
    }

    // MARK: - Event Counts (for local analytics)

    var sessionEventCount: Int { sessionLogs.count }

    func countEvents(of type: MetricEvent) -> Int {
        sessionLogs.filter { $0.event == type }.count
    }
}
