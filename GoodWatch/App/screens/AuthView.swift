import SwiftUI
import AuthenticationServices
import GoogleSignIn

// Screen 0.5: Optional Auth View
// Sign up / Sign in page after landing with Google + Apple
struct AuthView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var isLoading: Bool = false
    @State private var loadingMessage: String = ""
    @State private var errorMessage: String?
    @State private var newsletterOptIn: Bool = true
    @State private var newsletterEmail: String = ""

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Logo
                AppLogo(size: 80)

                Spacer().frame(height: 32)

                // Title
                Text("Save your preferences")
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)

                Spacer().frame(height: 8)

                // Subtitle
                Text("Sign in to keep your watch history")
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)

                Spacer().frame(height: 48)

                // Sign in with Apple (custom button for consistent styling)
                Button {
                    triggerAppleSignIn()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 22, weight: .medium))
                        Text("Sign in with Apple")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(GWColors.authButtonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(GWColors.authButtonBackground)
                    .cornerRadius(25)
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .accessibilityIdentifier("auth_apple_sign_in")

                Spacer().frame(height: 12)

                // Sign in with Google (custom button - matches Apple button style)
                Button {
                    handleGoogleSignIn()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(GWColors.authButtonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(GWColors.authButtonBackground)
                    .cornerRadius(25)
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .accessibilityIdentifier("auth_google_sign_in")

                Spacer().frame(height: 12)

                // Sign in with Facebook
                Button {
                    handleFacebookSignIn()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "f.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                        Text("Continue with Facebook")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "1877F2"))
                    .cornerRadius(25)
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .accessibilityIdentifier("auth_facebook_sign_in")

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(GWTypography.small())
                        .foregroundColor(.red)
                        .padding(.top, 16)
                        .padding(.horizontal, GWSpacing.screenPadding)
                }

                Spacer().frame(height: 28)

                // Newsletter opt-in
                VStack(spacing: 10) {
                    Button {
                        newsletterOptIn.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: newsletterOptIn ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(newsletterOptIn ? GWColors.gold : GWColors.lightGray.opacity(0.5))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Get the GoodWatch Weekly")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(GWColors.white)

                                Text("Curated picks, hidden gems, and what to watch this weekend.")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(GWColors.lightGray.opacity(0.7))
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Divider
                HStack {
                    Rectangle()
                        .fill(GWColors.surfaceBorder)
                        .frame(height: 1)
                    Text("or")
                        .font(GWTypography.small())
                        .foregroundColor(GWColors.lightGray)
                        .padding(.horizontal, 16)
                    Rectangle()
                        .fill(GWColors.surfaceBorder)
                        .frame(height: 1)
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 24)

                // Skip Button (Anonymous)
                Button {
                    handleAnonymousSignIn()
                } label: {
                    Text("Continue without account")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.lg)
                                .stroke(GWColors.surfaceBorder, lineWidth: 1)
                        )
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .accessibilityIdentifier("auth_skip")
                .padding(.bottom, 48)
            }
            .opacity(contentOpacity)

            // Loading overlay with descriptive message
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(GWColors.gold)
                        .scaleEffect(1.5)
                    if !loadingMessage.isEmpty {
                        Text(loadingMessage)
                            .font(GWTypography.small())
                            .foregroundColor(GWColors.lightGray)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1
            }
        }
    }

    // MARK: - Auth Handlers

    private func triggerAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInDelegate.shared
        controller.presentationContextProvider = AppleSignInDelegate.shared
        AppleSignInDelegate.shared.onComplete = { result in
            handleAppleSignIn(result: result)
        }
        controller.performRequests()
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isLoading = true
        loadingMessage = "Connecting to Apple..."
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Cache display name from Apple (only available on first sign-in)
                if let fullName = appleIDCredential.fullName {
                    let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                    let name = parts.joined(separator: " ")
                    if !name.isEmpty {
                        UserDefaults.standard.set(name, forKey: "gw_user_display_name")
                    }
                }
                // Provision local user instantly — navigate without waiting for Supabase
                let appleEmail = appleIDCredential.email
                let localUser = GWUser(
                    id: UUID(),
                    auth_provider: AuthProvider.apple.rawValue,
                    email: appleEmail,
                    device_id: appleIDCredential.user,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    last_active_at: nil
                )
                UserService.shared.currentUser = localUser
                UserService.shared.currentProfile = GWUserProfile.empty(userId: localUser.id)
                UserService.shared.isAuthenticated = true
                UserDefaults.standard.set(localUser.id.uuidString, forKey: "gw_user_id")

                isLoading = false
                loadingMessage = ""
                onContinue()

                // Background: reconcile with Supabase + newsletter
                let optIn = self.newsletterOptIn
                let credential = appleIDCredential
                Task {
                    do {
                        let reconciledUser = try await UserService.shared.signInWithApple(credential: credential)
                        if reconciledUser.id != localUser.id {
                            await MainActor.run {
                                UserService.shared.currentUser = reconciledUser
                                UserDefaults.standard.set(reconciledUser.id.uuidString, forKey: "gw_user_id")
                            }
                        }
                    } catch {
                        #if DEBUG
                        print("Supabase Apple auth background sync error: \(error.localizedDescription)")
                        #endif
                    }
                    if optIn { await subscribeToNewsletterIfOptedIn() }
                }
            } else {
                isLoading = false
                loadingMessage = ""
                errorMessage = "Could not get Apple credentials"
            }
        case .failure(let error):
            isLoading = false
            loadingMessage = ""
            let nsError = error as NSError

            #if DEBUG
            print("[ERROR] Apple Sign In error: \(error.localizedDescription) (code: \(nsError.code))")
            #endif

            if nsError.code == ASAuthorizationError.canceled.rawValue {
                // User cancelled - no error message needed
                return
            } else if nsError.code == ASAuthorizationError.notHandled.rawValue ||
                      nsError.code == ASAuthorizationError.unknown.rawValue ||
                      nsError.code == ASAuthorizationError.notInteractive.rawValue ||
                      nsError.code == ASAuthorizationError.invalidResponse.rawValue {
                // Various auth failures - fall back to anonymous silently
                Task {
                    await handleFallbackToAnonymous(provider: "Apple")
                }
            } else {
                // Show error but offer fallback
                errorMessage = "Apple Sign In unavailable. Tap 'Continue without account' below."
            }
        }
    }

    private func handleGoogleSignIn() {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        print("[GW-AUTH] T+0.0s: Google sign-in button tapped")
        #endif
        isLoading = true
        loadingMessage = "Connecting to Google..."
        errorMessage = nil

        // Get the root view controller for presenting Google Sign-In
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller"
            isLoading = false
            loadingMessage = ""
            return
        }

        // Perform Google Sign-In
        // Note: The SDK's token exchange takes 5-10s on slow WiFi — this is expected.
        // The loading message reassures the user while Google's servers respond.
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            #if DEBUG
            print("[GW-AUTH] T+\(String(format: "%.1f", CFAbsoluteTimeGetCurrent()-t0))s: Google callback fired")
            #endif

            if let error = error {
                #if DEBUG
                print("[GW-AUTH] Google error: \(error.localizedDescription)")
                #endif
                isLoading = false
                loadingMessage = ""
                let nsError = error as NSError

                // Check if user cancelled
                if nsError.code == GIDSignInError.canceled.rawValue {
                    return
                }

                Task {
                    await handleFallbackToAnonymous(provider: "Google")
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                isLoading = false
                loadingMessage = ""
                errorMessage = "Could not get Google credentials"
                return
            }

            let accessToken = user.accessToken.tokenString

            // Cache display name from Google profile for Profile tab
            if let name = user.profile?.name, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "gw_user_display_name")
            }

            // Provision local user instantly — navigate without waiting for Supabase
            let email = user.profile?.email
            let localUser = GWUser(
                id: UUID(),
                auth_provider: AuthProvider.google.rawValue,
                email: email,
                device_id: UserService.shared.deviceId,
                created_at: ISO8601DateFormatter().string(from: Date()),
                last_active_at: nil
            )
            UserService.shared.currentUser = localUser
            UserService.shared.currentProfile = GWUserProfile.empty(userId: localUser.id)
            UserService.shared.isAuthenticated = true
            UserDefaults.standard.set(localUser.id.uuidString, forKey: "gw_user_id")

            #if DEBUG
            print("[GW-AUTH] T+\(String(format: "%.1f", CFAbsoluteTimeGetCurrent()-t0))s: Local user provisioned, navigating")
            #endif

            isLoading = false
            loadingMessage = ""
            onContinue()

            // Background: reconcile with Supabase + newsletter
            let optIn = self.newsletterOptIn
            Task {
                do {
                    let reconciledUser = try await UserService.shared.signInWithGoogle(
                        idToken: idToken,
                        accessToken: accessToken
                    )
                    // Update local user if Supabase returned existing account
                    if reconciledUser.id != localUser.id {
                        await MainActor.run {
                            UserService.shared.currentUser = reconciledUser
                            UserDefaults.standard.set(reconciledUser.id.uuidString, forKey: "gw_user_id")
                        }
                    }
                } catch {
                    #if DEBUG
                    print("[GW-AUTH] Supabase background sync error: \(error.localizedDescription)")
                    #endif
                }
                if optIn { await self.subscribeToNewsletterIfOptedIn() }
            }
        }
    }

    private func handleFacebookSignIn() {
        isLoading = true
        loadingMessage = "Connecting to Facebook..."
        errorMessage = nil

        Task {
            do {
                let user = try await UserService.shared.signInWithFacebook()
                // Cache display name from email if available
                if let email = user.email, !email.isEmpty {
                    let name = email.components(separatedBy: "@").first ?? email
                    if UserDefaults.standard.string(forKey: "gw_user_display_name") == nil {
                        UserDefaults.standard.set(name, forKey: "gw_user_display_name")
                    }
                }
                // Navigate immediately — newsletter in background
                let optIn = self.newsletterOptIn
                await MainActor.run {
                    isLoading = false
                    loadingMessage = ""
                    onContinue()
                }
                if optIn { await subscribeToNewsletterIfOptedIn() }
            } catch {
                let nsError = error as NSError
                // ASWebAuthenticationSessionError.canceledLogin = 1
                if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                    // User cancelled - no error message needed
                    await MainActor.run { isLoading = false; loadingMessage = "" }
                    return
                }
                // Facebook Sign-In failed - fall back to anonymous
                #if DEBUG
                print("Facebook Sign-In error: \(error.localizedDescription)")
                #endif
                await handleFallbackToAnonymous(provider: "Facebook")
            }
        }
    }

    /// Falls back to anonymous sign-in when OAuth fails.
    /// Provisions a local user instantly so the user is never stuck.
    private func handleFallbackToAnonymous(provider: String) async {
        // Provision local anonymous user instantly (zero network)
        let localUser = GWUser.anonymous(deviceId: UserService.shared.deviceId)
        await MainActor.run {
            UserService.shared.currentUser = localUser
            UserService.shared.currentProfile = GWUserProfile.empty(userId: localUser.id)
            UserService.shared.isAuthenticated = true
            UserDefaults.standard.set(localUser.id.uuidString, forKey: "gw_user_id")
            isLoading = false
            loadingMessage = ""
            #if DEBUG
            print("[AUTH] \(provider) sign-in failed, continuing with local anonymous user \(localUser.id.uuidString)")
            #endif
            onSkip()
        }
        // Background: sync to Supabase (fire-and-forget)
        Task { await UserService.shared.syncLocalUserToSupabase() }
    }

    /// "Continue without account" — navigates instantly, syncs in background.
    /// Creates a local anonymous user with a UUID so all downstream tracking
    /// (AuthGuard, MetricsService, TagWeightStore, interactions) works immediately.
    private func handleAnonymousSignIn() {
        // Provision local anonymous user instantly (zero network)
        let localUser = GWUser.anonymous(deviceId: UserService.shared.deviceId)
        UserService.shared.currentUser = localUser
        UserService.shared.currentProfile = GWUserProfile.empty(userId: localUser.id)
        UserService.shared.isAuthenticated = true
        UserDefaults.standard.set(localUser.id.uuidString, forKey: "gw_user_id")

        // Navigate immediately — zero wait
        onSkip()

        // Background: sync to Supabase + newsletter (fire-and-forget)
        let optIn = newsletterOptIn
        Task {
            await UserService.shared.syncLocalUserToSupabase()
            if optIn { await subscribeToNewsletterIfOptedIn() }
        }
    }

    // MARK: - Newsletter

    /// Subscribe the user to the newsletter if they opted in
    private func subscribeToNewsletterIfOptedIn() async {
        guard newsletterOptIn else { return }

        // Get email from auth provider or use device_id as placeholder
        let email = UserService.shared.currentUserEmail
            ?? "\(UserDefaults.standard.string(forKey: "gw_device_id") ?? UUID().uuidString)@device.goodwatch.movie"

        let deviceId = UserDefaults.standard.string(forKey: "gw_device_id") ?? ""
        let userId = UserDefaults.standard.string(forKey: "gw_user_id")

        var payload: [String: Any] = [
            "email": email,
            "device_id": deviceId,
            "source": "app_auth_screen"
        ]
        if let uid = userId {
            payload["user_id"] = uid
        }

        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/newsletter_subscribers") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        // Use upsert to avoid duplicate email errors
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await GWNetworkSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                #if DEBUG
                print(httpResponse.statusCode < 300 ? "Newsletter: subscribed" : "Newsletter: failed (\(httpResponse.statusCode))")
                #endif
            }
        } catch {
            #if DEBUG
            print("Newsletter subscription error: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Apple Sign In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInDelegate()
    var onComplete: ((Result<ASAuthorization, Error>) -> Void)?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onComplete?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onComplete?(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window for presenting the Apple Sign-In sheet
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
