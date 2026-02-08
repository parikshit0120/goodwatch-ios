import Foundation
import UIKit
import AuthenticationServices

// MARK: - User Service
final class UserService: ObservableObject {
    static let shared = UserService()

    @Published var currentUser: GWUser?
    @Published var currentProfile: GWUserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false

    private let defaults = UserDefaults.standard
    private let deviceIdKey = "gw_device_id"
    private let userIdKey = "gw_user_id"

    private var baseURL: String { SupabaseConfig.url }
    private var anonKey: String { SupabaseConfig.anonKey }

    private init() {
        loadCachedUser()
    }

    // MARK: - Device ID Management
    var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: deviceIdKey)
        return newId
    }

    var cachedUserId: UUID? {
        guard let idString = defaults.string(forKey: userIdKey) else { return nil }
        return UUID(uuidString: idString)
    }

    /// The authenticated user's email (if available)
    var currentUserEmail: String? {
        currentUser?.email
    }

    private func cacheUserId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: userIdKey)
    }

    // MARK: - Load Cached User
    private func loadCachedUser() {
        guard let userId = cachedUserId else { return }
        Task {
            do {
                let user = try await fetchUser(id: userId)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
                let profile = try await fetchProfile(userId: userId)
                await MainActor.run {
                    self.currentProfile = profile
                }
            } catch {
                #if DEBUG
                print("Failed to load cached user: \(error)")
                #endif
            }
        }
    }

    // MARK: - Anonymous Sign In
    func signInAnonymously() async throws -> GWUser {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Check if anonymous user already exists for this device
        if let existingUser = try? await fetchUserByDeviceId(deviceId) {
            await MainActor.run {
                self.currentUser = existingUser
                self.isAuthenticated = true
            }
            cacheUserId(existingUser.id)

            // Fetch or create profile
            if let profile = try? await fetchProfile(userId: existingUser.id) {
                await MainActor.run { self.currentProfile = profile }
            } else {
                let newProfile = try await createProfile(userId: existingUser.id)
                await MainActor.run { self.currentProfile = newProfile }
            }

            return existingUser
        }

        // Create new anonymous user
        let user = GWUser.anonymous(deviceId: deviceId)
        let createdUser = try await createUser(user)
        cacheUserId(createdUser.id)

        await MainActor.run {
            self.currentUser = createdUser
            self.isAuthenticated = true
        }

        // Create empty profile
        let profile = try await createProfile(userId: createdUser.id)
        await MainActor.run { self.currentProfile = profile }

        return createdUser
    }

    // MARK: - Google Sign In
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> GWUser {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Exchange tokens with Supabase Auth
        let authResponse = try await exchangeGoogleToken(idToken: idToken, accessToken: accessToken)

        // Check if user exists
        if let existingUser = try? await fetchUserByEmail(authResponse.email) {
            // Upgrade anonymous user if needed
            if existingUser.auth_provider == AuthProvider.anonymous.rawValue {
                let upgradedUser = try await upgradeUser(existingUser, toProvider: .google, email: authResponse.email)
                await MainActor.run {
                    self.currentUser = upgradedUser
                    self.isAuthenticated = true
                }
                return upgradedUser
            }
            await MainActor.run {
                self.currentUser = existingUser
                self.isAuthenticated = true
            }
            cacheUserId(existingUser.id)
            return existingUser
        }

        // Create new user
        let user = GWUser(
            id: UUID(),
            auth_provider: AuthProvider.google.rawValue,
            email: authResponse.email,
            device_id: deviceId,
            created_at: ISO8601DateFormatter().string(from: Date()),
            last_active_at: nil
        )
        let createdUser = try await createUser(user)
        cacheUserId(createdUser.id)

        await MainActor.run {
            self.currentUser = createdUser
            self.isAuthenticated = true
        }

        // Create profile
        let profile = try await createProfile(userId: createdUser.id)
        await MainActor.run { self.currentProfile = profile }

        return createdUser
    }

    // MARK: - Apple Sign In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> GWUser {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Get the identity token - required for Apple Sign In
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            #if DEBUG
            print("❌ Apple Sign In: No identity token received")
            #endif
            throw UserServiceError.authFailed
        }

        // Extract email from identity token JWT if not provided directly
        // Apple only provides email on FIRST sign-in, subsequent sign-ins won't have it
        var email = credential.email ?? ""
        if email.isEmpty {
            // Try to extract from JWT
            email = extractEmailFromJWT(identityToken) ?? ""
        }

        let appleUserId = credential.user

        #if DEBUG
        print("🍎 Apple Sign In: userId=\(appleUserId), email=\(email.isEmpty ? "(not provided)" : email)")
        #endif

        // Check if user exists by Apple user ID (stored in device_id field for Apple users)
        if let existingUser = try? await fetchUserByDeviceId(appleUserId) {
            await MainActor.run {
                self.currentUser = existingUser
                self.isAuthenticated = true
            }
            cacheUserId(existingUser.id)

            // Fetch profile
            if let profile = try? await fetchProfile(userId: existingUser.id) {
                await MainActor.run { self.currentProfile = profile }
            }

            return existingUser
        }

        // Create new user
        let user = GWUser(
            id: UUID(),
            auth_provider: AuthProvider.apple.rawValue,
            email: email.isEmpty ? nil : email,
            device_id: appleUserId, // Store Apple user ID for future lookups
            created_at: ISO8601DateFormatter().string(from: Date()),
            last_active_at: nil
        )
        let createdUser = try await createUser(user)
        cacheUserId(createdUser.id)

        await MainActor.run {
            self.currentUser = createdUser
            self.isAuthenticated = true
        }

        // Create profile
        let profile = try await createProfile(userId: createdUser.id)
        await MainActor.run { self.currentProfile = profile }

        return createdUser
    }

    /// Extract email from Apple identity JWT token
    private func extractEmailFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Pad to multiple of 4 for base64 decoding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let payloadData = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let email = payload["email"] as? String else {
            return nil
        }
        return email
    }

    // MARK: - Profile Updates (Incremental)

    func updateMoodPreference(_ mood: String) async throws {
        guard var profile = currentProfile else { throw UserServiceError.noProfile }

        profile.mood_preferences.current_mood = mood
        profile.mood_preferences.mood_history.append(
            MoodEntry(mood: mood, timestamp: ISO8601DateFormatter().string(from: Date()))
        )
        if !profile.mood_preferences.preferred_moods.contains(mood) {
            profile.mood_preferences.preferred_moods.append(mood)
        }

        let updated = try await updateProfile(profile)
        await MainActor.run { self.currentProfile = updated }
    }

    func updatePlatforms(_ platforms: [String]) async throws {
        guard var profile = currentProfile else { throw UserServiceError.noProfile }

        profile.platforms = platforms
        let updated = try await updateProfile(profile)
        await MainActor.run { self.currentProfile = updated }
    }

    func updateRuntimePreference(maxRuntime: Int, range: RuntimeRange) async throws {
        guard var profile = currentProfile else { throw UserServiceError.noProfile }

        profile.runtime_preferences.max_runtime = maxRuntime
        profile.runtime_preferences.preferred_range = range
        let updated = try await updateProfile(profile)
        await MainActor.run { self.currentProfile = updated }
    }

    func updateLanguages(_ languages: [String]) async throws {
        guard var profile = currentProfile else { throw UserServiceError.noProfile }

        profile.preferred_languages = languages
        let updated = try await updateProfile(profile)
        await MainActor.run { self.currentProfile = updated }
    }

    func updateConfidenceLevel(delta: Double) async throws {
        guard var profile = currentProfile else { throw UserServiceError.noProfile }

        profile.confidence_level = max(0, min(1, profile.confidence_level + delta))
        let updated = try await updateProfile(profile)
        await MainActor.run { self.currentProfile = updated }
    }

    // MARK: - API Calls

    private func createUser(_ user: GWUser) async throws -> GWUser {
        let urlString = "\(baseURL)/rest/v1/users"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(user)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Create user error: \(body)")
            }
            #endif
            throw UserServiceError.createFailed
        }

        let users = try JSONDecoder().decode([GWUser].self, from: data)
        guard let created = users.first else { throw UserServiceError.createFailed }
        return created
    }

    private func fetchUser(id: UUID) async throws -> GWUser {
        let urlString = "\(baseURL)/rest/v1/users?id=eq.\(id.uuidString)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let users = try JSONDecoder().decode([GWUser].self, from: data)
        guard let user = users.first else { throw UserServiceError.notFound }
        return user
    }

    private func fetchUserByDeviceId(_ deviceId: String) async throws -> GWUser {
        let urlString = "\(baseURL)/rest/v1/users?device_id=eq.\(deviceId)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let users = try JSONDecoder().decode([GWUser].self, from: data)
        guard let user = users.first else { throw UserServiceError.notFound }
        return user
    }

    private func fetchUserByEmail(_ email: String) async throws -> GWUser {
        let urlString = "\(baseURL)/rest/v1/users?email=eq.\(email)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let users = try JSONDecoder().decode([GWUser].self, from: data)
        guard let user = users.first else { throw UserServiceError.notFound }
        return user
    }

    private func upgradeUser(_ user: GWUser, toProvider provider: AuthProvider, email: String) async throws -> GWUser {
        let urlString = "\(baseURL)/rest/v1/users?id=eq.\(user.id.uuidString)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let updateData: [String: Any] = [
            "auth_provider": provider.rawValue,
            "email": email
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UserServiceError.updateFailed
        }

        let users = try JSONDecoder().decode([GWUser].self, from: data)
        guard let updated = users.first else { throw UserServiceError.updateFailed }
        return updated
    }

    private func createProfile(userId: UUID) async throws -> GWUserProfile {
        let urlString = "\(baseURL)/rest/v1/user_profiles"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let profile = GWUserProfile.empty(userId: userId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(profile)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Create profile error: \(body)")
            }
            #endif
            throw UserServiceError.createFailed
        }

        let profiles = try JSONDecoder().decode([GWUserProfile].self, from: data)
        guard let created = profiles.first else { throw UserServiceError.createFailed }
        return created
    }

    private func fetchProfile(userId: UUID) async throws -> GWUserProfile {
        let urlString = "\(baseURL)/rest/v1/user_profiles?user_id=eq.\(userId.uuidString)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let profiles = try JSONDecoder().decode([GWUserProfile].self, from: data)
        guard let profile = profiles.first else { throw UserServiceError.notFound }
        return profile
    }

    private func updateProfile(_ profile: GWUserProfile) async throws -> GWUserProfile {
        let urlString = "\(baseURL)/rest/v1/user_profiles?user_id=eq.\(profile.user_id.uuidString)"
        guard let url = URL(string: urlString) else { throw UserServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(profile)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("Update profile error: \(body)")
            }
            #endif
            throw UserServiceError.updateFailed
        }

        let profiles = try JSONDecoder().decode([GWUserProfile].self, from: data)
        guard let updated = profiles.first else { throw UserServiceError.updateFailed }
        return updated
    }

    // MARK: - Google Token Exchange (placeholder)
    private func exchangeGoogleToken(idToken: String, accessToken: String) async throws -> (email: String, userId: String) {
        // In production, this would call Supabase Auth
        // For now, decode the JWT to get email
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64Encoded: String(parts[1]).padding(toLength: ((String(parts[1]).count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let email = payload["email"] as? String else {
            throw UserServiceError.authFailed
        }
        return (email: email, userId: UUID().uuidString)
    }
}

// MARK: - Errors
enum UserServiceError: Error {
    case invalidURL
    case createFailed
    case updateFailed
    case notFound
    case noProfile
    case authFailed
    case networkError(Error)
}
