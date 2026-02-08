import SwiftUI

// Screen 4: Emotional Hook
// The pitch - "Your perfect pick is ready"
// Also performs catalog availability pre-check before proceeding
struct EmotionalHookView: View {
    let userContext: UserContext
    let onShowMe: () -> Void
    let onBack: () -> Void
    let onChangePlatforms: () -> Void
    let onChangeRuntime: () -> Void

    @State private var chaosOpacity: Double = 0
    @State private var text1Opacity: Double = 0
    @State private var text2Opacity: Double = 0
    @State private var text3Opacity: Double = 0
    @State private var buttonOpacity: Double = 0

    // Availability check state
    @State private var isCheckingAvailability = false
    @State private var showAvailabilityAlert = false
    @State private var availabilityIssue: GWAvailabilityIssue?

    private let engine = GWRecommendationEngine.shared

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(GWTypography.body(weight: .medium))
                        }
                        .foregroundColor(GWColors.lightGray)
                    }

                    Spacer()

                    Text("4/4")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.top, 16)

                Spacer()

                // Chaos/Scribble Visual (representing choice paralysis)
                ChaosVisual()
                    .frame(width: 120, height: 120)
                    .opacity(chaosOpacity)

                Spacer().frame(height: 60)

                // Copy - The Hook
                VStack(spacing: 16) {
                    Text("Your perfect pick\nis ready.")
                        .font(GWTypography.headline())
                        .foregroundColor(GWColors.white)
                        .multilineTextAlignment(.center)
                        .opacity(text1Opacity)

                    Text("Matched to your mood,\ntime, and taste.")
                        .font(GWTypography.headline())
                        .foregroundColor(GWColors.white)
                        .multilineTextAlignment(.center)
                        .opacity(text2Opacity)

                    Text("One tap. One pick. Done.")
                        .font(GWTypography.headline())
                        .foregroundColor(GWColors.gold)
                        .opacity(text3Opacity)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Show me Button (Gold CTA)
                Button {
                    checkAvailabilityAndProceed()
                } label: {
                    HStack(spacing: 8) {
                        if isCheckingAvailability {
                            ProgressView()
                                .tint(GWColors.black)
                        }
                        Text(isCheckingAvailability ? "Checking..." : "Show me")
                            .font(GWTypography.button())
                    }
                    .foregroundColor(GWColors.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(LinearGradient.goldGradient)
                    .cornerRadius(GWRadius.lg)
                }
                .disabled(isCheckingAvailability)
                .opacity(buttonOpacity)
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 60)
            }

            // Availability Issue Alert
            if showAvailabilityAlert, let issue = availabilityIssue {
                AvailabilityAlertOverlay(
                    issue: issue,
                    onPrimaryAction: {
                        showAvailabilityAlert = false
                        switch issue.suggestedAction {
                        case .changePlatforms, .changeLanguage:
                            onChangePlatforms()
                        case .changeRuntime:
                            onChangeRuntime()
                        }
                    },
                    onDismiss: {
                        showAvailabilityAlert = false
                    }
                )
            }
        }
        .onAppear {
            animateSequence()
        }
    }

    // MARK: - Availability Pre-Check

    private func checkAvailabilityAndProceed() {
        isCheckingAvailability = true

        Task {
            // Determine content type filter based on user selection
            // If user selected Series/Binge, fetch only TV shows
            let contentTypeFilter: String? = userContext.requiresSeries ? "tv" : "movie"

            // Get user's language preferences for filtered fetch
            let userLanguages = userContext.languages.map { $0.rawValue }

            // Fetch movies/series with language filter applied at database level
            // This ensures we get relevant movies for the user's language, not just top-rated globally
            guard let movies = try? await SupabaseService.shared.fetchMoviesForAvailabilityCheck(
                languages: userLanguages,
                contentType: contentTypeFilter,
                acceptCount: 0,  // First-time user
                limit: 500
            ) else {
                // Can't check - proceed anyway and let normal flow handle errors
                await MainActor.run {
                    isCheckingAvailability = false
                    proceedToShowMe()
                }
                return
            }

            // Build profile from context
            let profile = GWUserProfileComplete.from(
                context: userContext,
                userId: "precheck",
                excludedIds: []
            )

            // Get user maturity info for content filter
            let userUUID = UserService.shared.currentUser?.id ?? UUID()
            let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userUUID)
            let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

            // Check availability
            let gwMovies = movies.map { GWMovie(from: $0) }

            #if DEBUG
            print("🔍 DEBUG: Fetched \(movies.count) raw movies, converted to \(gwMovies.count) GWMovies")
            let kalamMovies = gwMovies.filter { $0.title.lowercased().contains("kalam") }
            for k in kalamMovies {
                print("   Found Kalam: \(k.title), lang=\(k.language), runtime=\(k.runtime), platforms=\(k.platforms), score=\(k.goodscore), votes=\(k.voteCount), tags=\(k.tags)")
            }
            if kalamMovies.isEmpty {
                print("   ⚠️ No Kalam movie found in fetch results!")
            }
            #endif

            let availability = engine.checkCatalogAvailability(
                movies: gwMovies,
                profile: profile,
                contentFilter: contentFilter
            )

            await MainActor.run {
                isCheckingAvailability = false

                #if DEBUG
                print("📊 Catalog check: \(availability.combinedMatches) matches out of \(availability.totalMovies) movies")
                print("   Platform: \(availability.platformMatches), Language: \(availability.languageMatches), Runtime: \(availability.runtimeMatches)")
                print("   ContentType: \(availability.contentTypeMatches), Quality: \(availability.qualityMatches)")
                print("   User platforms: \(profile.platforms), languages: \(profile.preferredLanguages)")
                print("   User runtime: \(profile.runtimeWindow.min)-\(profile.runtimeWindow.max), requiresSeries: \(profile.requiresSeries)")

                // Debug: Print first few movies that have platform match
                let primeMovies = gwMovies.filter { movie in
                    let providers = movie.platforms
                    return providers.contains { $0.lowercased().contains("amazon") || $0.lowercased().contains("prime") }
                }
                print("   🔍 Found \(primeMovies.count) Prime movies")

                // Check each filter individually for these movies
                for movie in primeMovies.prefix(10) {
                    let langMatch = profile.preferredLanguages.isEmpty || profile.preferredLanguages.contains { lang in
                        let l = lang.lowercased()
                        let m = movie.language.lowercased()
                        return m.contains(l) || (l == "hindi" && m == "hi") || (l == "english" && m == "en")
                    }
                    let runtimeMatch = movie.runtime >= profile.runtimeWindow.min && movie.runtime <= profile.runtimeWindow.max
                    let qualityMatch = movie.goodscore >= 7.5
                    let contentMatch = movie.contentType?.lowercased() == "movie" || movie.contentType == nil

                    print("   🎬 \(movie.title): lang=\(movie.language)[\(langMatch ? "✓" : "✗")], runtime=\(movie.runtime)[\(runtimeMatch ? "✓" : "✗")], score=\(movie.goodscore)[\(qualityMatch ? "✓" : "✗")], type=\(movie.contentType ?? "nil")[\(contentMatch ? "✓" : "✗")]")
                }
                #endif

                if availability.hasAvailableMovies {
                    // Good to go!
                    proceedToShowMe()
                } else if let issue = availability.issue {
                    // Show alert with specific guidance
                    availabilityIssue = issue
                    showAvailabilityAlert = true
                } else {
                    // Unknown issue - proceed and let normal flow handle
                    proceedToShowMe()
                }
            }
        }
    }

    private func proceedToShowMe() {
        // SECTION 4: Persist onboarding step to Keychain for resume support
        GWKeychainManager.shared.storeOnboardingStep(5)
        onShowMe()
    }

    private func animateSequence() {
        withAnimation(.easeOut(duration: 0.5)) {
            chaosOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            text1Opacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
            text2Opacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.2)) {
            text3Opacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.6)) {
            buttonOpacity = 1
        }
    }
}

// MARK: - Availability Alert Overlay

struct AvailabilityAlertOverlay: View {
    let issue: GWAvailabilityIssue
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Alert card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.goldGradient)

                // Title
                Text(issue.title)
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)

                // Message
                Text(issue.message)
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer().frame(height: 8)

                // Primary action button
                Button(action: onPrimaryAction) {
                    Text(primaryButtonText)
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.goldGradient)
                        .cornerRadius(GWRadius.md)
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Try Anyway")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }
            }
            .padding(24)
            .background(GWColors.darkGray)
            .cornerRadius(GWRadius.xl)
            .padding(.horizontal, 32)
        }
    }

    private var primaryButtonText: String {
        switch issue.suggestedAction {
        case .changePlatforms:
            return "Change Platforms"
        case .changeLanguage:
            return "Change Language"
        case .changeRuntime:
            return "Change Duration"
        }
    }
}

// Animated gold rings pulsing outward - representing discovery/excitement
struct ChaosVisual: View {
    @State private var pulse1: CGFloat = 0.6
    @State private var pulse2: CGFloat = 0.4
    @State private var pulse3: CGFloat = 0.2
    @State private var rotation: Double = 0
    @State private var innerGlow: Double = 0.5

    var body: some View {
        ZStack {
            // Outer pulsing rings
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                GWColors.gold.opacity(0.8 - Double(i) * 0.15),
                                GWColors.gold.opacity(0.4 - Double(i) * 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5 - CGFloat(i) * 0.2
                    )
                    .frame(width: CGFloat(30 + i * 25), height: CGFloat(30 + i * 25))
                    .scaleEffect(i == 0 ? pulse1 : (i == 1 ? pulse2 : (i == 2 ? pulse3 : 1.0)))
                    .opacity(i == 0 ? Double(pulse1) : (i == 1 ? Double(pulse2) * 0.8 : (i == 2 ? Double(pulse3) * 0.6 : 0.3)))
            }

            // Rotating dashed orbit
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 8])
                )
                .foregroundStyle(LinearGradient.goldGradient)
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(rotation))

            // Inner glowing core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            GWColors.gold.opacity(innerGlow),
                            GWColors.gold.opacity(innerGlow * 0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)

            // Center dot
            Circle()
                .fill(GWColors.gold)
                .frame(width: 8, height: 8)
                .shadow(color: GWColors.gold.opacity(0.8), radius: 10)
        }
        .onAppear {
            // Pulsing animations
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse1 = 1.2
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
                pulse2 = 1.15
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.6)) {
                pulse3 = 1.1
            }

            // Rotation animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            // Inner glow pulse
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                innerGlow = 0.9
            }
        }
    }
}
