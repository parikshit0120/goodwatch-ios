import SwiftUI

// Screen 6: Main Screen (The Entire Product)
// GoodScore reveal with animation - THE CRITICAL MOMENT
struct MainScreenView: View {
    let movie: Movie
    let goodScore: Int
    let userOTTs: [OTTPlatform]
    let userMood: String?  // Mood selection from onboarding (for causal "why this" copy)
    let onWatchNow: (OTTProvider) -> Void
    let onNotTonight: () -> Void
    let onAlreadySeen: () -> Void
    let onStartOver: (() -> Void)?

    // Default initializer for backwards compatibility
    init(
        movie: Movie,
        goodScore: Int,
        userOTTs: [OTTPlatform],
        userMood: String? = nil,
        onWatchNow: @escaping (OTTProvider) -> Void,
        onNotTonight: @escaping () -> Void,
        onAlreadySeen: @escaping () -> Void,
        onStartOver: (() -> Void)? = nil
    ) {
        self.movie = movie
        self.goodScore = goodScore
        self.userOTTs = userOTTs
        self.userMood = userMood
        self.onWatchNow = onWatchNow
        self.onNotTonight = onNotTonight
        self.onAlreadySeen = onAlreadySeen
        self.onStartOver = onStartOver
    }

    @Environment(\.openURL) private var openURL

    // FUTURE-PROOFING: Decision timing tracker (PLACEHOLDER)
    // Tracks how long user takes to make a decision
    // Quick decisions (< 3s) = strong preference/dislike
    // Hesitant decisions (> 30s) = uncertainty
    @State private var decisionTiming = GWDecisionTiming()

    // Animation states
    @State private var posterOpacity: Double = 0
    @State private var posterScale: CGFloat = 0.95
    @State private var titleOpacity: Double = 0
    @State private var scoreBoxOpacity: Double = 0
    @State private var scoreBoxScale: CGFloat = 0.9
    @State private var scoreNumberOpacity: Double = 0
    @State private var scoreNumberScale: CGFloat = 0.8
    @State private var scoreGlow: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 20
    @State private var secondaryOpacity: Double = 0
    @State private var whyThisOpacity: Double = 0
    @State private var alsoAvailableOpacity: Double = 0

    // MARK: - Causal "Why This" Copy
    // Connects the recommendation to user's stated mood preference

    /// Generate causal copy that explains why this movie matches user's mood
    private var whyThisCopy: String? {
        guard let mood = userMood?.lowercased() else { return nil }

        // Get movie's emotional tags
        let movieTags = GWMovie(from: movie).tags

        switch mood {
        case "feel-good", "feel_good", "feelgood":
            if movieTags.contains("feel_good") || movieTags.contains("uplifting") {
                return "You wanted feel-good. This won't disappoint."
            }
            return "You wanted something uplifting. This fits."

        case "easy_watch", "easy watch", "light":
            if movieTags.contains("light") || movieTags.contains("background_friendly") {
                return "You wanted easy. This won't demand much."
            }
            return "You wanted light. This delivers."

        case "surprise_me", "surprise me", "neutral":
            return "You said surprise me. Here's our best pick."

        case "gripping", "intense":
            if movieTags.contains("tense") || movieTags.contains("high_energy") {
                return "You wanted gripping. Buckle up."
            }
            return "You wanted intensity. This has it."

        case "dark_&_heavy", "dark & heavy", "dark":
            if movieTags.contains("dark") || movieTags.contains("heavy") {
                return "You wanted heavy. This goes there."
            }
            return "You wanted dark. Here it is."

        default:
            return nil
        }
    }

    // MARK: - Multi-Platform Display Logic (PART 7)
    // Primary CTA = user's selected platform
    // "Also available on" = other platforms the movie is on

    /// Providers matching user's platforms (for primary CTA button)
    private var matchingProviders: [OTTProvider] {
        movie.matchingProviders(for: userOTTs)
    }

    /// Providers NOT in user's platforms (for "Also available on" section)
    private var otherProviders: [OTTProvider] {
        movie.otherProviders(excludingUserPlatforms: userOTTs)
    }

    /// Whether to show "Also available on" section
    private var hasOtherProviders: Bool {
        !otherProviders.isEmpty
    }

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("GoodWatch")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient.goldGradient)

                    Spacer()

                    if let startOver = onStartOver {
                        Button(action: startOver) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 16))
                                .foregroundColor(GWColors.lightGray)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)

                // Divider
                Rectangle()
                    .fill(GWColors.surfaceBorder)
                    .frame(height: 1)

                // Content
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    // Film Poster - smaller to fit screen
                    ZStack {
                        if let url = movie.posterURL, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    posterSkeleton
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 240, maxHeight: 340)
                                        .cornerRadius(GWRadius.xl)
                                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                                case .failure:
                                    posterSkeleton
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            posterSkeleton
                        }
                    }
                    .opacity(posterOpacity)
                    .scaleEffect(posterScale)

                    Spacer().frame(height: 16)

                    // Film Title
                    Text(movie.title)
                        .font(GWTypography.title())
                        .foregroundColor(GWColors.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                        .opacity(titleOpacity)

                    Spacer().frame(height: 4)

                    // Film Metadata
                    HStack(spacing: 8) {
                        if !movie.yearString.isEmpty {
                            Text(movie.yearString)
                        }
                        Text("·")
                        Text(formatRuntime(movie.runtimeMinutes))
                    }
                    .font(GWTypography.small())
                    .foregroundColor(GWColors.lightGray)
                    .opacity(titleOpacity)

                    // CAUSAL "WHY THIS" COPY
                    // Connects recommendation to user's stated mood preference
                    if let whyThis = whyThisCopy {
                        Text(whyThis)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GWColors.gold.opacity(0.9))
                            .italic()
                            .padding(.top, 12)
                            .opacity(whyThisOpacity)
                    }

                    // 2-LINE PITCH: overview + credits
                    VStack(spacing: 6) {
                        // Line 1: Brief overview
                        if let overview = movie.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(GWColors.lightGray.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 32)
                        }

                        // Line 2: Director + Cast pitch
                        if let pitch = movie.pitchLine {
                            Text(pitch)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GWColors.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 8)
                    .opacity(whyThisOpacity)

                    Spacer().frame(height: 14)

                    // GoodScore Display (THE HERO ELEMENT)
                    GoodScoreDisplay(
                        score: goodScore,
                        boxOpacity: scoreBoxOpacity,
                        boxScale: scoreBoxScale,
                        numberOpacity: scoreNumberOpacity,
                        numberScale: scoreNumberScale,
                        glowIntensity: scoreGlow
                    )

                    Spacer()

                    // Watch Now Button (Gold CTA) - Primary platform
                    if let provider = matchingProviders.first {
                        Button {
                            // PLACEHOLDER: Record decision timing
                            var timing = decisionTiming
                            timing.recordDecision()
                            #if DEBUG
                            if let duration = timing.decisionDurationSeconds {
                                let type = timing.isQuickDecision ? "QUICK" : (timing.isHesitantDecision ? "HESITANT" : "NORMAL")
                                print("⏱️ Decision timing: \(String(format: "%.1f", duration))s (\(type)) - WATCH_NOW")
                            }
                            #endif

                            openOTT(provider)
                            onWatchNow(provider)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                Text("Watch on \(provider.displayName)")
                                    .font(GWTypography.button())
                            }
                            .foregroundColor(GWColors.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(LinearGradient.goldGradient)
                            .cornerRadius(GWRadius.lg)
                        }
                        .padding(.horizontal, GWSpacing.screenPadding)
                        .opacity(buttonOpacity)
                        .offset(y: buttonOffset)
                    }

                    // "Also available on" section (PART 7)
                    // Shows OTHER platforms the movie is available on
                    if hasOtherProviders {
                        VStack(spacing: 8) {
                            Text("Also available on")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GWColors.lightGray.opacity(0.8))

                            HStack(spacing: 12) {
                                ForEach(otherProviders.prefix(4), id: \.id) { provider in
                                    Button {
                                        openOTT(provider)
                                    } label: {
                                        Text(provider.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GWColors.white.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(GWColors.darkGray)
                                            .cornerRadius(GWRadius.sm)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: GWRadius.sm)
                                                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .opacity(alsoAvailableOpacity)
                    }

                    Spacer().frame(height: 16)

                    // Secondary Actions
                    HStack(spacing: 16) {
                        Button("Not tonight") {
                            // PLACEHOLDER: Record decision timing
                            var timing = decisionTiming
                            timing.recordDecision()
                            #if DEBUG
                            if let duration = timing.decisionDurationSeconds {
                                let type = timing.isQuickDecision ? "QUICK" : (timing.isHesitantDecision ? "HESITANT" : "NORMAL")
                                print("⏱️ Decision timing: \(String(format: "%.1f", duration))s (\(type)) - NOT_TONIGHT")
                            }
                            #endif

                            onNotTonight()
                        }
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)

                        Rectangle()
                            .fill(GWColors.lightGray.opacity(0.3))
                            .frame(width: 1, height: 20)

                        Button("Already seen") {
                            // PLACEHOLDER: Record decision timing
                            var timing = decisionTiming
                            timing.recordDecision()
                            #if DEBUG
                            if let duration = timing.decisionDurationSeconds {
                                let type = timing.isQuickDecision ? "QUICK" : (timing.isHesitantDecision ? "HESITANT" : "NORMAL")
                                print("⏱️ Decision timing: \(String(format: "%.1f", duration))s (\(type)) - ALREADY_SEEN")
                            }
                            #endif

                            onAlreadySeen()
                        }
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                    }
                    .opacity(secondaryOpacity)

                    Spacer().frame(height: 32)
                }
            }
        }
        .onAppear {
            runRevealAnimation()
        }
    }

    private var posterSkeleton: some View {
        RoundedRectangle(cornerRadius: GWRadius.xl)
            .fill(GWColors.darkGray)
            .frame(width: 240, height: 340)
            .overlay(
                ProgressView()
                    .tint(GWColors.lightGray)
            )
    }

    private func formatRuntime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private func openOTT(_ provider: OTTProvider) {
        if let deepLink = provider.deepLinkURL {
            if UIApplication.shared.canOpenURL(deepLink) {
                openURL(deepLink)
                return
            }
        }
        if let webURL = provider.webURL {
            openURL(webURL)
        }
    }

    // MARK: - THE REVEAL ANIMATION (CRITICAL)
    private func runRevealAnimation() {
        // Step 1: Poster Fade In (400ms)
        withAnimation(.easeOut(duration: 0.4)) {
            posterOpacity = 1
            posterScale = 1
        }

        // 200ms pause, then title
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                titleOpacity = 1
            }
        }

        // Step 2: GoodScore Box Appears (after 700ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.1)) {
                scoreBoxOpacity = 1
                scoreBoxScale = 1
            }
        }

        // Step 3: GoodScore Number Reveal (THE MOMENT - 500ms spring)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scoreNumberOpacity = 1
                scoreNumberScale = 1.05
                scoreGlow = 1.5
            }

            // Scale back to 1.0 and stabilize glow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scoreNumberScale = 1.0
                    scoreGlow = 1.0
                }
            }
        }

        // Step 3.5: "Why This" causal copy fades in (after 1.1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                whyThisOpacity = 1
            }
        }

        // Step 4: Watch Now Button Slides Up (after 1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                buttonOpacity = 1
                buttonOffset = 0
            }
        }

        // Step 4.5: "Also available on" fades in (after 1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                alsoAvailableOpacity = 1
            }
        }

        // Step 5: Secondary Actions Fade In (after 1.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeIn(duration: 0.2)) {
                secondaryOpacity = 1
            }
        }
    }
}

// MARK: - GoodScore Display Component
struct GoodScoreDisplay: View {
    let score: Int
    let boxOpacity: Double
    let boxScale: CGFloat
    let numberOpacity: Double
    let numberScale: CGFloat
    let glowIntensity: Double

    @State private var innerGlowPulse: Double = 0

    private var confidenceLabel: String {
        if score >= 85 { return "High confidence" }
        if score >= 70 { return "Safe pick tonight" }
        return "Worth a watch"
    }

    var body: some View {
        VStack(spacing: 4) {
            // Score Number
            Text("\(score)")
                .font(GWTypography.score())
                .foregroundStyle(LinearGradient.goldGradient)
                .opacity(numberOpacity)
                .scaleEffect(numberScale)
                .shadow(color: GWColors.gold.opacity(0.4 * glowIntensity), radius: 16 * glowIntensity)

            // Label
            Text("GOODSCORE")
                .font(GWTypography.tiny(weight: .semibold))
                .foregroundColor(GWColors.lightGray)
                .tracking(2)
                .opacity(numberOpacity)

            // Micro-label (confidence indicator)
            Text(confidenceLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GWColors.gold.opacity(0.8))
                .opacity(numberOpacity)
        }
        .frame(width: 160, height: 130)
        .background(
            ZStack {
                GWColors.darkGray
                // Inner glow pulse effect
                RoundedRectangle(cornerRadius: GWRadius.lg)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                GWColors.gold.opacity(0.15 * innerGlowPulse),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.lg)
                .stroke(GWColors.gold.opacity(0.3), lineWidth: 2)
        )
        .cornerRadius(GWRadius.lg)
        .shadow(color: GWColors.gold.opacity(0.25 * glowIntensity), radius: 32 * glowIntensity)
        .opacity(boxOpacity)
        .scaleEffect(boxScale)
        .onChange(of: numberOpacity) { _, newValue in
            if newValue > 0 {
                // One-time inner glow pulse on reveal
                withAnimation(.easeOut(duration: 0.6)) {
                    innerGlowPulse = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        innerGlowPulse = 0.3
                    }
                }
            }
        }
    }
}
