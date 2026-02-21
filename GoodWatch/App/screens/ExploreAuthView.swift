import SwiftUI
import AuthenticationServices
import GoogleSignIn

// ============================================
// EXPLORE AUTH VIEW
// ============================================
// Dedicated auth screen for the Explore & Search journey.
// Sign-up is MANDATORY — no "Continue without account" option.
// After successful auth, navigates to ExploreView (not Mood selector).
// Includes benefit messaging to convince sign-up.

struct ExploreAuthView: View {
    let onSignedIn: () -> Void    // Called after successful sign-in → navigate to Explore
    let onBack: () -> Void        // Go back to Landing

    @State private var contentOpacity: Double = 0
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var newsletterOptIn: Bool = true

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(GWColors.white)
                                .padding(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer().frame(height: 16)

                    // Logo
                    AppLogo(size: 72)

                    Spacer().frame(height: 24)

                    // Title
                    Text("Sign up to Explore")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LinearGradient.goldGradient)

                    Spacer().frame(height: 8)

                    Text("Create a free account to unlock all features")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GWColors.lightGray)

                    Spacer().frame(height: 28)

                    // Benefits
                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow(
                            icon: "heart.fill",
                            title: "Save your Watchlist",
                            desc: "Heart movies and build your personal list."
                        )
                        benefitRow(
                            icon: "magnifyingglass",
                            title: "Discover & Search",
                            desc: "Browse 22,000+ movies with smart filters."
                        )
                        benefitRow(
                            icon: "sparkles",
                            title: "New Releases",
                            desc: "Latest drops on Netflix, Prime, Hotstar & more."
                        )
                        benefitRow(
                            icon: "brain.head.profile",
                            title: "Smarter Picks",
                            desc: "Your activity helps us recommend better."
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 36)

                    // Sign in buttons
                    VStack(spacing: 12) {
                        // Sign in with Apple
                        Button {
                            triggerAppleSignIn()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 22, weight: .medium))
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "E8E8E8"))
                            .cornerRadius(25)
                        }

                        // Sign in with Google
                        Button {
                            handleGoogleSignIn()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 22, weight: .medium))
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "E8E8E8"))
                            .cornerRadius(25)
                        }

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
                    }
                    .padding(.horizontal, GWSpacing.screenPadding)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(GWTypography.small())
                            .foregroundColor(.red)
                            .padding(.top, 16)
                            .padding(.horizontal, GWSpacing.screenPadding)
                    }

                    Spacer().frame(height: 20)

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

                    Spacer().frame(height: 40)
                }
            }
            .opacity(contentOpacity)

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(GWColors.gold)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1
            }
        }
    }

    // MARK: - Benefits Row

    private func benefitRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(GWColors.gold)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GWColors.white)

                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(GWColors.lightGray)
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
                Task {
                    do {
                        _ = try await UserService.shared.signInWithApple(credential: appleIDCredential)
                        await subscribeToNewsletterIfOptedIn()
                        await MainActor.run {
                            isLoading = false
                            onSignedIn()
                        }
                    } catch {
                        // Apple OAuth succeeded but Supabase user creation failed
                        // Fall back to anonymous so user isn't blocked from Explore
                        #if DEBUG
                        print("⚠️ Apple Sign-In: OAuth OK but Supabase failed: \(error.localizedDescription)")
                        print("   Falling back to anonymous sign-in for Explore access")
                        #endif
                        await fallbackToAnonymousForExplore(provider: "Apple")
                    }
                }
            } else {
                isLoading = false
                errorMessage = "Could not get Apple credentials"
            }
        case .failure(let error):
            isLoading = false
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                return  // User cancelled — no error
            }
            // Apple Sign-In itself failed (not just Supabase) — try anonymous fallback
            #if DEBUG
            print("❌ Apple Sign In error: \(error.localizedDescription) (code: \(nsError.code))")
            #endif
            Task {
                await fallbackToAnonymousForExplore(provider: "Apple")
            }
        }
    }

    private func handleGoogleSignIn() {
        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller"
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                isLoading = false
                let nsError = error as NSError
                if nsError.code == GIDSignInError.canceled.rawValue {
                    return  // User cancelled
                }
                #if DEBUG
                print("❌ Google Sign-In error: \(error.localizedDescription)")
                #endif
                // Google Sign-In failed — try anonymous fallback
                Task {
                    await fallbackToAnonymousForExplore(provider: "Google")
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                isLoading = false
                errorMessage = "Could not get Google credentials"
                return
            }

            let accessToken = user.accessToken.tokenString

            // Cache display name from Google profile for Profile tab
            if let name = user.profile?.name, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "gw_user_display_name")
            }

            Task {
                do {
                    _ = try await UserService.shared.signInWithGoogle(
                        idToken: idToken,
                        accessToken: accessToken
                    )
                    await self.subscribeToNewsletterIfOptedIn()
                    await MainActor.run {
                        isLoading = false
                        onSignedIn()
                    }
                } catch {
                    // Google OAuth succeeded but Supabase failed — fall back to anonymous
                    #if DEBUG
                    print("⚠️ Google Sign-In: OAuth OK but Supabase failed: \(error.localizedDescription)")
                    #endif
                    await fallbackToAnonymousForExplore(provider: "Google")
                }
            }
        }
    }

    private func handleFacebookSignIn() {
        isLoading = true
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
                await subscribeToNewsletterIfOptedIn()
                await MainActor.run {
                    isLoading = false
                    onSignedIn()
                }
            } catch {
                let nsError = error as NSError
                // ASWebAuthenticationSessionError.canceledLogin = 1
                if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                    await MainActor.run { isLoading = false }
                    return
                }
                #if DEBUG
                print("Facebook Sign-In error: \(error.localizedDescription)")
                #endif
                await fallbackToAnonymousForExplore(provider: "Facebook")
            }
        }
    }

    // MARK: - Fallback to Anonymous

    /// When OAuth fails (either at provider level or Supabase level),
    /// fall back to anonymous sign-in so user can still access Explore.
    /// This ensures users aren't permanently blocked from the Explore journey.
    private func fallbackToAnonymousForExplore(provider: String) async {
        do {
            _ = try await UserService.shared.signInAnonymously()
            await subscribeToNewsletterIfOptedIn()
            await MainActor.run {
                isLoading = false
                #if DEBUG
                print("✅ Fallback to anonymous succeeded — proceeding to Explore")
                #endif
                onSignedIn()
            }
        } catch {
            // Even anonymous failed — proceed anyway (same as AuthView behavior)
            // User can still browse Explore without server-side profile
            await MainActor.run {
                isLoading = false
                #if DEBUG
                print("⚠️ Even anonymous fallback failed: \(error.localizedDescription) — proceeding anyway")
                #endif
                onSignedIn()
            }
        }
    }

    // MARK: - Newsletter

    private func subscribeToNewsletterIfOptedIn() async {
        guard newsletterOptIn else { return }

        let email = UserService.shared.currentUserEmail
            ?? "\(UserDefaults.standard.string(forKey: "gw_device_id") ?? UUID().uuidString)@device.goodwatch.movie"

        let deviceId = UserDefaults.standard.string(forKey: "gw_device_id") ?? ""
        let userId = UserDefaults.standard.string(forKey: "gw_user_id")

        var payload: [String: Any] = [
            "email": email,
            "device_id": deviceId,
            "source": "app_explore_auth"
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
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("Newsletter subscription error: \(error.localizedDescription)")
            #endif
        }
    }
}
