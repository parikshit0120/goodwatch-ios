import SwiftUI
import FirebaseCrashlytics
import PostHog

// ============================================
// ROOT FLOW VIEW - Navigation Controller
// ============================================
//
// Manages the entire user flow from landing to recommendation.
// Tracks current screen via an enum and accumulates UserContext
// across onboarding screens.
//
// Flow:
//   Landing -> Auth -> MoodSelector -> PlatformSelector
//   -> DurationSelector -> ConfidenceMoment
//   -> MainScreen (with RejectionSheet overlay)
//
// Resume:
//   On launch, checks GWKeychainManager for saved onboarding step
//   and resumes from that point if user is authenticated.
// ============================================

struct RootFlowView: View {

    // MARK: - Screen Enum

    enum Screen: Int, Comparable {
        case landing = 0
        case auth = 1
        case moodSelector = 2
        case platformSelector = 3
        case languagePriority = 12  // v1.3: between platform and duration
        case durationSelector = 4
        case confidenceMoment = 6
        case mainScreen = 7
        case enjoyScreen = 8
        case feedback = 9
        case explore = 10
        case exploreAuth = 11

        static func < (lhs: Screen, rhs: Screen) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - State

    @State private var currentScreen: Screen = .landing
    @State private var userContext: UserContext = .default

    // Recommendation state
    @State private var currentMovie: Movie?
    @State private var currentGoodScore: Int = 0
    @State private var isLoadingRecommendation: Bool = false
    @State private var recommendationError: String?
    @State private var currentFallbackLevel: GWFallbackLevel = .none
    @State private var excludedMovieIds: Set<UUID> = []
    @State private var recommendationReady: Bool = false
    @State private var confidenceMinTimeElapsed: Bool = false

    // Rejection sheet
    @State private var showRejectionSheet: Bool = false

    // Rejection → next movie loading states (Fix: black screen after rejection)
    @State private var isLoadingNextMovie: Bool = false
    @State private var showNoMoreMatches: Bool = false

    // Session tracking
    @State private var sessionRecommendationCount: Int = 0

    // Multi-pick state (Progressive Pick System)
    @State private var recommendedPicks: [GWMovie] = []
    @State private var validMoviePool: [GWMovie] = []    // Cached valid GWMovie pool for replacements
    @State private var rawMoviePool: [Movie] = []        // Cached raw Movie pool for lookups
    @State private var pickCount: Int = 1                // How many picks to show (5/4/3/2/1)
    @State private var replacedPositions: Set<Int> = []  // Positions that got replacements
    @State private var totalReplacements: Int = 0        // Session-wide replacement counter (hard cap: 5)
    @State private var currentProfile: GWUserProfileComplete? = nil  // Cached profile for replacements

    // International pick state (dubbed content — INV-L09)
    @State private var internationalPick: GWMovie? = nil

    // Trend boost state (INV-T01/T02/T03)
    @State private var currentTrendTag: String? = nil
    @State private var trendBoostsByUUID: [String: GWTrendBoost] = [:]

    // Trailer state (FIX 10)
    @State private var currentTrailerKey: String? = nil
    @State private var carouselTrailerKeys: [String: String] = [:]  // movie ID -> YouTube key

    // Decision timing: tracks when current recommendation was shown
    // Used to measure how long user deliberates before accept/reject
    @State private var recommendationShownTime: Date? = nil

    // Feedback state
    @State private var pendingFeedback: FeedbackPromptData? = nil

    // UGC Review state
    @State private var showReviewPrompt: Bool = false
    @State private var reviewMovieTitle: String = ""
    @State private var reviewMovieId: String = ""

    // Transition animation
    @State private var screenTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    // Recent Picks sheet + bubble
    @State private var showRecentPicksSheet: Bool = false
    @State private var showRecentPicksBubble: Bool = false

    // Suppression pool exhausted popup (Task 1d)
    @State private var showSuppressionExhaustedPopup: Bool = false

    // Rating banner state (Task 6)
    @State private var showRatingBanner: Bool = false
    @State private var pendingRatingForBanner: PendingRating? = nil

    // Fix 1: Final Gate — session-scoped shown tracking
    @State private var sessionShownIds: Set<UUID> = []
    @State private var sessionReplacementCount: Int = 0

    // Fix 3: Replacement limit banner
    @State private var showReplacementLimitMessage: Bool = false

    // Update checker
    @StateObject private var updateChecker = GWUpdateChecker.shared

    // Services
    private let engine = GWRecommendationEngine.shared

    // MARK: - Recommendation Persistence

    /// Session persistence DISABLED: force quit always returns to landing.
    /// Save/restore removed to prevent stale data and ensure fresh picks each session.
    private func saveCurrentPicks() {
        // No-op: session persistence disabled
    }

    /// Session persistence DISABLED: always returns false.
    private func restorePicksIfNeeded() -> Bool {
        return false
    }

    // Fix 1: Final Gate — gates ALL display-time currentMovie assignments
    // Checks sessionShownIds and suppression before allowing display.
    // If movie is blocked, pulls next valid from fallbackPool or sets nil.
    private func assignCurrentMovie(_ movie: Movie, fallbackPool: [Movie]) {
        isLoadingNextMovie = false
        showNoMoreMatches = false

        if sessionShownIds.contains(movie.id) || GWSuppressionManager.shared.isSuppressed(movieId: movie.id) {
            if let alt = fallbackPool.first(where: { !sessionShownIds.contains($0.id) && !GWSuppressionManager.shared.isSuppressed(movieId: $0.id) }) {
                currentMovie = alt
                sessionShownIds.insert(alt.id)
            } else {
                // No fallback — show no-more-matches state, NOT black screen
                currentMovie = nil
                showNoMoreMatches = true
            }
        } else {
            currentMovie = movie
            sessionShownIds.insert(movie.id)
        }
    }

    /// Clear saved picks from UserDefaults
    private func clearSavedPicks() {
        UserDefaults.standard.removeObject(forKey: "gw_current_picks")
        UserDefaults.standard.removeObject(forKey: "gw_current_pick_count")
        UserDefaults.standard.removeObject(forKey: "gw_current_raw_movies")
        UserDefaults.standard.removeObject(forKey: "gw_current_single_movie")
        UserDefaults.standard.removeObject(forKey: "gw_current_good_score")
        UserDefaults.standard.removeObject(forKey: "gw_current_screen")
        UserDefaults.standard.removeObject(forKey: "gw_picks_timestamp")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            screenView
                .transition(screenTransition)
                .animation(.easeInOut(duration: 0.35), value: currentScreen)

            // Rejection sheet overlay
            if showRejectionSheet {
                RejectionSheetView(
                    onReason: { reason in
                        handleRejectionWithReason(reason)
                    },
                    onJustShowAnother: {
                        handleShowAnother()
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showRejectionSheet = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: showRejectionSheet)
            }

            // Loading overlay for recommendation fetching
            if isLoadingRecommendation && currentScreen == .mainScreen {
                recommendationLoadingOverlay
            }

            // Update available banner (top of screen, non-blocking)
            VStack {
                GWUpdateBanner(checker: updateChecker)
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: updateChecker.updateAvailable)

            // Fix 3: Replacement limit banner (auto-dismiss after 3s)
            if showReplacementLimitMessage {
                VStack {
                    Spacer()
                    Text("You've explored enough for now. Try a new mood or platform.")
                        .font(GWTypography.body())
                        .foregroundColor(GWColors.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(GWColors.darkGray.opacity(0.95))
                        .cornerRadius(GWRadius.md)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: showReplacementLimitMessage)
                .zIndex(90)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { showReplacementLimitMessage = false }
                    }
                }
            }

            // UGC Review prompt overlay (shown on enjoy screen after delay)
            if showReviewPrompt {
                GWReviewPromptView(
                    movieTitle: reviewMovieTitle,
                    movieId: reviewMovieId,
                    onSubmit: { rating, text in
                        guard let userId = AuthGuard.shared.currentUserId else { return }
                        Task {
                            await GWReviewService.submitReview(
                                userId: userId.uuidString,
                                movieId: reviewMovieId,
                                rating: rating,
                                reviewText: text
                            )
                        }
                    },
                    onSkip: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showReviewPrompt = false
                        }
                    }
                )
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: showReviewPrompt)
                .zIndex(100)
            }

            // Recent Picks sheet overlay (auto-shows on landing if picks exist)
            if showRecentPicksSheet {
                let picks = RecentPicksService.shared.getPicks()
                if !picks.isEmpty {
                    RecentPicksSheet(
                        picks: picks,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showRecentPicksSheet = false
                            }
                            // FIX 1: Use DispatchQueue for reliable bubble appearance
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showRecentPicksBubble = true
                                }
                            }
                        },
                        onClearAll: {
                            RecentPicksService.shared.clear()
                            withAnimation(.easeOut(duration: 0.25)) {
                                showRecentPicksSheet = false
                                showRecentPicksBubble = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: showRecentPicksSheet)
                    .zIndex(90)
                }
            }

            // Task 1d: Suppression pool exhausted popup
            if showSuppressionExhaustedPopup {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSuppressionExhaustedPopup = false
                        }
                    }

                VStack(spacing: 20) {
                    Text("You've seen the best of the bunch")
                        .font(GWTypography.headline())
                        .foregroundColor(GWColors.white)
                        .multilineTextAlignment(.center)

                    Text("Most movies matching your taste have already been shown. We can revisit some or you can come back later for fresh picks.")
                        .font(GWTypography.body())
                        .foregroundColor(GWColors.lightGray)
                        .multilineTextAlignment(.center)

                    Button {
                        guard let userId = AuthGuard.shared.currentUserId else { return }
                        GWSuppressionManager.shared.temporarilyLiftSuppression(for: userId.uuidString)
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSuppressionExhaustedPopup = false
                        }
                        // Re-fetch with suppression lifted
                        Task { await fetchRecommendation() }
                    } label: {
                        Text("Show me anyway")
                            .font(GWTypography.button())
                            .foregroundColor(GWColors.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GWColors.gold)
                            .cornerRadius(GWRadius.md)
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSuppressionExhaustedPopup = false
                        }
                    } label: {
                        Text("Not now")
                            .font(GWTypography.body())
                            .foregroundColor(GWColors.lightGray)
                    }
                }
                .padding(24)
                .background(GWColors.darkGray)
                .cornerRadius(GWRadius.lg)
                .padding(.horizontal, 32)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: showSuppressionExhaustedPopup)
                .zIndex(110)
            }

            // Recent Picks floating bubble (bottom-right, shows after sheet dismiss)
            // FIX 1: Only show on landing screen, hidden during onboarding/recommendation
            if showRecentPicksBubble && !showRecentPicksSheet && currentScreen == .landing {
                let pickCount = RecentPicksService.shared.getPicks().count
                if pickCount > 0 {
                    RecentPicksBubble(count: pickCount) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRecentPicksSheet = true
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: showRecentPicksBubble)
                    .zIndex(80)
                }
            }

            // Task 6: Rating banner — "How was it?" shown on landing for unrated movies
            if showRatingBanner, let pending = pendingRatingForBanner, currentScreen == .landing {
                VStack {
                    Spacer()
                    GWRatingBannerView(
                        pending: pending,
                        onRate: { thumbsUp in
                            // Task 7: Record rating for session summary
                            GWJourneyTracker.shared.recordRating()
                            guard let userId = AuthGuard.shared.currentUserId else { return }
                            Task {
                                await GWRatingService.shared.rateMovie(
                                    movieId: pending.movieId,
                                    thumbsUp: thumbsUp,
                                    userId: userId.uuidString
                                )
                            }
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showRatingBanner = false
                                pendingRatingForBanner = nil
                            }
                        }
                    )
                    .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: showRatingBanner)
                .zIndex(85)
            }
        }
        .onAppear {
            // Session restore DISABLED: force quit always returns to landing screen.
            // Old picks are cleared on launch to prevent stale data.
            clearSavedPicks()
            resumeFromSavedState()
            checkForPendingFeedback()
            // Load suppression cache BEFORE showing Recent Picks (fixes rejected movies leaking into recent picks)
            Task {
                if let userId = AuthGuard.shared.currentUserId {
                    await GWSuppressionManager.shared.loadSuppressionCache(userId: userId.uuidString)
                }
                // Auto-show Recent Picks sheet on landing if picks exist (after suppression loaded)
                if currentScreen == .landing && !RecentPicksService.shared.getPicks().isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRecentPicksSheet = true
                        }
                    }
                }
            }
            // Task 6: Check for pending rating banner
            if let pending = GWRatingService.shared.getPendingForBanner() {
                pendingRatingForBanner = pending
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showRatingBanner = true
                    }
                }
            }
            // Check for app updates (rate-limited, non-blocking)
            updateChecker.checkForUpdate()
            // Fetch remote mood config and feature flags early (non-blocking)
            Task {
                await GWMoodConfigService.shared.fetchRemoteConfig()
                await GWFeatureFlags.shared.fetchFlags()
            }
            // Reconcile interaction points (non-blocking)
            if let userId = AuthGuard.shared.currentUserId {
                Task {
                    await GWInteractionPoints.shared.reconcile(userId: userId.uuidString)
                }
            }
            // Sync watchlist + tag weights from Supabase (3-second timeout, non-blocking)
            Task {
                await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await WatchlistManager.shared.syncFromRemote()
                    }
                    group.addTask {
                        await TagWeightStore.shared.syncFromRemote()
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        throw CancellationError()
                    }
                    // Wait for whichever finishes first: both syncs or the timeout
                    do {
                        for try await _ in group {
                            // Each completion arrives here
                        }
                    } catch {
                        // Timeout fired — cancel remaining tasks and move on
                        group.cancelAll()
                    }
                }
            }
        }
        // FIX 1: Backup bubble trigger via onChange — handles edge cases where onDismiss misses
        .onChange(of: showRecentPicksSheet) { _, isShowing in
            if !isShowing && currentScreen == .landing && !RecentPicksService.shared.getPicks().isEmpty && !showRecentPicksBubble {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showRecentPicksBubble = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gwNavigateToRecommendation)) { _ in
            // User tapped a notification — take them to landing to start a fresh pick
            // This handles: weekend pick taps, re-engagement taps, rich notification taps
            if currentScreen != .landing {
                returnToLanding()
            }
        }
        .paywallListener()
    }

    // MARK: - Screen Router

    @ViewBuilder
    private var screenView: some View {
        switch currentScreen {
        case .landing:
            LandingView(
                onContinue: {
                    // Task 7: Track onboarding started
                    GWJourneyTracker.shared.trackOnboardingStarted()
                    // Skip auth if user is already signed in (via Explore or previous session)
                    if UserService.shared.isAuthenticated || UserService.shared.cachedUserId != nil {
                        navigateTo(.moodSelector)
                    } else {
                        navigateTo(.auth)
                    }
                },
                onExplore: {
                    // Two separate journeys:
                    // If already signed in → go straight to Explore
                    // If not → ExploreAuthView (mandatory sign-up)
                    //
                    // Check both:
                    //   - isAuthenticated (set after async loadCachedUser completes)
                    //   - cachedUserId (synchronous UserDefaults, survives force quit)
                    // The cachedUserId check handles the race condition where
                    // loadCachedUser hasn't completed yet but user IS signed in.
                    // cachedUserId is only set after a SUCCESSFUL user creation in Supabase.
                    if UserService.shared.isAuthenticated || UserService.shared.cachedUserId != nil {
                        navigateTo(.explore)
                    } else {
                        navigateTo(.exploreAuth)
                    }
                },
                onDebugSkip: {
                    #if DEBUG
                    debugSkipToRecommendation()
                    #endif
                }
            )

        case .auth:
            AuthView(
                onContinue: {
                    // Authenticated via Google/Apple
                    navigateTo(.moodSelector)
                },
                onSkip: {
                    // Anonymous / skip
                    navigateTo(.moodSelector)
                }
            )

        case .moodSelector:
            MoodSelectorView(
                ctx: $userContext,
                onNext: {
                    MetricsService.shared.track(.onboardingStepCompleted, properties: ["step": "mood_selector", "step_number": 1])
                    // Task 7: Track mood selection in PostHog
                    GWJourneyTracker.shared.trackMoodSelected(mood: userContext.mood.rawValue)

                    // If onboarding memory exists (within 30 days), skip to recommendations
                    #if DEBUG
                    print("[ONBOARDING-MEMORY] hasSavedSelections: \(GWOnboardingMemory.shared.hasSavedSelections)")
                    if let saved = GWOnboardingMemory.shared.load() {
                        print("[ONBOARDING-MEMORY] mood: \(userContext.mood), platforms: \(saved.otts.map { $0.rawValue })")
                        print("[ONBOARDING-MEMORY] languages (ordered): \(saved.languages.map { $0.rawValue })")
                        print("[ONBOARDING-MEMORY] duration: \(saved.minDuration)-\(saved.maxDuration)m, series: \(saved.requiresSeries)")
                    }
                    #endif
                    if let saved = GWOnboardingMemory.shared.load(),
                       !saved.otts.isEmpty, !saved.languages.isEmpty {
                        userContext.otts = saved.otts
                        userContext.languages = saved.languages
                        userContext.minDuration = saved.minDuration
                        userContext.maxDuration = saved.maxDuration
                        userContext.requiresSeries = saved.requiresSeries
                        // Persist to Supabase (fire-and-forget)
                        Task {
                            let platformStrings = saved.otts.map { $0.rawValue }
                            let languageStrings = saved.languages.map { $0.rawValue }
                            try? await UserService.shared.updatePlatforms(platformStrings)
                            try? await UserService.shared.updateLanguages(languageStrings)
                        }
                        GWKeychainManager.shared.completeOnboarding()
                        userContext.saveToDefaults()
                        // Task 7: Track onboarding completed (skipped steps via memory)
                        GWJourneyTracker.shared.trackOnboardingCompleted(
                            mood: userContext.mood.rawValue,
                            platforms: userContext.otts.map { $0.rawValue },
                            skippedSteps: true
                        )
                        navigateTo(.confidenceMoment)
                        fetchRecommendation()
                    } else {
                        // Memory missing, expired, or incomplete — go through full onboarding
                        navigateTo(.platformSelector)
                    }
                },
                onBack: {
                    returnToLanding()
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .platformSelector:
            PlatformSelectorView(
                ctx: $userContext,
                onNext: {
                    MetricsService.shared.track(.onboardingStepCompleted, properties: ["step": "platform_selector", "step_number": 2])
                    // Task 7: Track platform selection in PostHog
                    GWJourneyTracker.shared.trackPlatformSelected(platforms: userContext.otts.map { $0.rawValue })
                    navigateTo(.languagePriority)
                },
                onBack: {
                    navigateBack(to: .moodSelector)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .languagePriority:
            LanguagePriorityView(
                ctx: $userContext,
                onNext: {
                    MetricsService.shared.track(.onboardingStepCompleted, properties: ["step": "language_priority", "step_number": 3])
                    navigateTo(.durationSelector)
                },
                onBack: {
                    navigateBack(to: .platformSelector)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .durationSelector:
            DurationSelectorView(
                ctx: $userContext,
                onNext: {
                    MetricsService.shared.track(.onboardingStepCompleted, properties: ["step": "duration_selector", "step_number": 4])
                    // Save onboarding memory NOW — before fetchRecommendation.
                    // This ensures selections persist even if recommendation fails
                    // or the user force-quits during the loading screen.
                    GWOnboardingMemory.shared.save(
                        otts: userContext.otts,
                        languages: userContext.languages,
                        minDuration: userContext.minDuration,
                        maxDuration: userContext.maxDuration,
                        requiresSeries: userContext.requiresSeries
                    )
                    // Task 7: Track onboarding completed (full flow)
                    GWJourneyTracker.shared.trackOnboardingCompleted(
                        mood: userContext.mood.rawValue,
                        platforms: userContext.otts.map { $0.rawValue },
                        skippedSteps: false
                    )
                    // Mark onboarding complete at preference selection, not recommendation fetch.
                    // Prevents onboarding loop if fetch fails or user kills app during loading.
                    GWKeychainManager.shared.completeOnboarding()
                    // v1.3: Skip EmotionalHook, go directly to ConfidenceMoment
                    navigateTo(.confidenceMoment)
                    fetchRecommendation()
                },
                onBack: {
                    navigateBack(to: .languagePriority)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .confidenceMoment:
            ConfidenceMomentView(onComplete: {
                confidenceMinTimeElapsed = true
                tryTransitionToMainScreen()
            })

        case .mainScreen:
            mainScreenContent

        case .enjoyScreen:
            enjoyScreenContent

        case .feedback:
            feedbackScreenContent

        case .explore:
            ExploreView(
                onClose: {
                    // Navigate back to wherever the user came from
                    if currentMovie != nil {
                        navigateBack(to: .mainScreen)
                    } else {
                        navigateBack(to: .landing)
                    }
                },
                onHome: {
                    // Home button — go back to landing to switch journeys
                    returnToLanding()
                }
            )

        case .exploreAuth:
            ExploreAuthView(
                onSignedIn: {
                    // After successful sign-up from Explore flow → go to Explore (NOT mood selector)
                    navigateTo(.explore)
                },
                onBack: {
                    // Back to landing
                    navigateBack(to: .landing)
                }
            )
        }
    }

    // MARK: - Main Screen Content

    @ViewBuilder
    private var mainScreenContent: some View {
        if pickCount > 1 && !recommendedPicks.isEmpty {
            // Multi-pick: show carousel
            PickCarouselView(
                picks: recommendedPicks,
                rawMovies: rawMoviePool,
                pickCount: pickCount,
                replacedPositions: replacedPositions,
                totalReplacements: totalReplacements,
                userOTTs: userContext.otts,
                userMood: userContext.intent.mood,
                trailerKeys: carouselTrailerKeys,
                onWatchNow: { movie, provider in
                    handleMultiPickWatchNow(movie: movie, provider: provider)
                },
                onReject: { gwMovie, reason in
                    handleCardRejection(gwMovie: gwMovie, reason: reason)
                },
                onStartOver: {
                    startOver()
                },
                onExplore: {
                    navigateTo(.explore)
                }
            )
        } else if let movie = currentMovie {
            // Single pick: existing MainScreenView (pickCount == 1)
            VStack(spacing: 0) {
                if currentFallbackLevel == .relaxedQuality {
                    QualityRelaxedBannerView()
                }

                #if DEBUG
                MainScreenView(
                    movie: movie,
                    goodScore: currentGoodScore,
                    userOTTs: userContext.otts,
                    userMood: userContext.intent.mood,
                    onWatchNow: { provider in
                        handleWatchNow(movie: movie, provider: provider)
                    },
                    onNotTonight: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRejectionSheet = true
                        }
                    },
                    onAlreadySeen: {
                        handleAlreadySeen(movie: movie)
                    },
                    onStartOver: {
                        startOver()
                    },
                    onExplore: {
                        navigateTo(.explore)
                    },
                    internationalPick: internationalPick,
                    trendTag: currentTrendTag,
                    trailerKey: currentTrailerKey,
                    isTopPick: currentFallbackLevel == .none,
                    debugInfo: debugOverlayInfo
                )
                #else
                MainScreenView(
                    movie: movie,
                    goodScore: currentGoodScore,
                    userOTTs: userContext.otts,
                    userMood: userContext.intent.mood,
                    onWatchNow: { provider in
                        handleWatchNow(movie: movie, provider: provider)
                    },
                    onNotTonight: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRejectionSheet = true
                        }
                    },
                    onAlreadySeen: {
                        handleAlreadySeen(movie: movie)
                    },
                    onStartOver: {
                        startOver()
                    },
                    onExplore: {
                        navigateTo(.explore)
                    },
                    internationalPick: internationalPick,
                    trendTag: currentTrendTag,
                    trailerKey: currentTrailerKey,
                    isTopPick: currentFallbackLevel == .none
                )
                #endif
            }
        } else if let error = recommendationError {
            noRecommendationView(message: error)
        } else if showNoMoreMatches {
            // No more matches after rejection — show actionable state, NOT black screen
            noRecommendationView(message: "You've seen everything for this mood. Try a different mood or platform.")
        } else if isLoadingNextMovie {
            // Pattern B: Loading next movie — systemBackground, never pure black
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        } else {
            // Still loading - show confidence moment style loading with safety timeout
            ConfidenceMomentView(onComplete: {})
                .onAppear {
                    // Safety timeout: if still loading after 15 seconds, show error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                        if currentScreen == .mainScreen && currentMovie == nil && recommendationError == nil && recommendedPicks.isEmpty && !showNoMoreMatches {
                            recommendationError = "Taking too long to find a match. Please try again."
                            isLoadingRecommendation = false
                        }
                    }
                }
        }
    }

    // MARK: - Enjoy Screen Content

    @ViewBuilder
    private var enjoyScreenContent: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            // Cached image — reused for both backdrop and thumbnail
            if let posterUrl = currentMovie?.posterURL(size: .w500) {
                GWCachedImageDual(url: posterUrl) { image in
                    ZStack {
                        // Blurred movie backdrop behind content
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: 12)
                            .brightness(-0.5)
                            .scaleEffect(1.1)
                            .clipped()
                            .ignoresSafeArea()

                        // Gradient overlay for text legibility
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: GWColors.black.opacity(0.3), location: 0),
                                .init(color: GWColors.black.opacity(0.2), location: 0.3),
                                .init(color: GWColors.black.opacity(0.6), location: 0.7),
                                .init(color: GWColors.black.opacity(0.95), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()

                        // Movie poster thumbnail (reuses same loaded image)
                        VStack(spacing: 24) {
                            Spacer()

                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 200)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)

                            enjoyScreenTextAndButtons
                        }
                    }
                }
            } else {
                // No poster URL — just show text content
                VStack(spacing: 24) {
                    Spacer()
                    enjoyScreenTextAndButtons
                }
            }
        }
        .onAppear {
            // Show review prompt after 2 seconds on the enjoy screen
            if let movie = currentMovie {
                reviewMovieTitle = movie.title
                reviewMovieId = movie.id.uuidString
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if currentScreen == .enjoyScreen {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showReviewPrompt = true
                        }
                    }
                }
            }

            // Auto-return to landing after 10 seconds if user doesn't interact
            // (extended from 5s to account for review prompt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if currentScreen == .enjoyScreen && !showReviewPrompt {
                    returnToLandingPreservingMemory()
                }
            }
        }
    }

    /// Shared text and button content for the Enjoy screen (used with and without poster)
    @ViewBuilder
    private var enjoyScreenTextAndButtons: some View {
        Text("Enjoy!")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(LinearGradient.goldGradient)

        if let title = currentMovie?.title {
            Text(title)
                .font(GWTypography.body(weight: .semibold))
                .foregroundColor(GWColors.white)
        }

        Text("Enjoy the pick.")
            .font(GWTypography.body(weight: .medium))
            .foregroundColor(GWColors.lightGray)

        Spacer()

        Button {
            returnToLandingPreservingMemory()
        } label: {
            Text("Pick another")
                .font(GWTypography.button())
                .foregroundColor(GWColors.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LinearGradient.goldGradient)
                .cornerRadius(GWRadius.lg)
        }
        .padding(.horizontal, GWSpacing.screenPadding)

        Button {
            returnToLandingPreservingMemory()
        } label: {
            Text("Done for tonight")
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }

        Spacer().frame(height: 40)
    }

    // MARK: - Feedback Screen Content

    @ViewBuilder
    private var feedbackScreenContent: some View {
        if let feedback = pendingFeedback, GWFeatureFlags.shared.isEnabled("feedback_v2") {
            GWWatchFeedbackView(
                movieTitle: feedback.movieTitle,
                movieId: feedback.movieId,
                posterURL: nil,
                onComplete: {
                    // GWWatchFeedbackView handles enforcer + Supabase internally
                    pendingFeedback = nil
                    returnToLandingPreservingMemory()
                }
            )
        } else if let feedback = pendingFeedback {
            PostWatchFeedbackView(
                feedbackData: feedback,
                onCompleted: {
                    pendingFeedback = nil
                    returnToLandingPreservingMemory()
                },
                onAbandoned: {
                    pendingFeedback = nil
                    returnToLandingPreservingMemory()
                },
                onSkipped: {
                    pendingFeedback = nil
                    returnToLandingPreservingMemory()
                }
            )
        } else {
            // Feedback was cleared while on this screen — go to landing
            LandingView(onContinue: {
                navigateTo(.auth)
            })
            .onAppear {
                navigateTo(.landing)
            }
        }
    }

    // MARK: - Feedback Helpers

    private func checkForPendingFeedback() {
        guard let userId = AuthGuard.shared.currentUserId else { return }

        // Clean up old feedback entries
        GWFeedbackEnforcer.shared.cleanupOldFeedback()

        // Check for overdue feedback
        if let feedback = GWFeedbackEnforcer.shared.getFeedbackPromptData(userId: userId.uuidString) {
            pendingFeedback = feedback
            navigateTo(.feedback)

            #if DEBUG
            print("[INFO] Showing overdue feedback for: \(feedback.movieTitle)")
            #endif
        }
    }

    /// Return to landing, preserving onboarding memory so user skips
    /// OTT/language/duration on next "Pick for me" (within 30 days).
    private func returnToLanding() {
        returnToLandingInternal(clearMemory: false)
    }

    /// Return to landing after watching / feedback — preserves onboarding memory
    /// so user skips OTT/language/duration on next "Pick for me"
    private func returnToLandingPreservingMemory() {
        returnToLandingInternal(clearMemory: false)
    }

    /// "Start Over" — returns to landing for a fresh mood pick.
    /// Preserves onboarding memory (OTT/language/duration) so the user
    /// only re-picks mood, never re-enters platforms/languages.
    private func startOver() {
        returnToLandingInternal(clearMemory: false)
    }

    private func returnToLandingInternal(clearMemory: Bool) {
        // Track onboarding abandonment if user is mid-onboarding
        let onboardingScreens: Set<Screen> = [.moodSelector, .platformSelector, .languagePriority, .durationSelector]
        if onboardingScreens.contains(currentScreen) {
            MetricsService.shared.track(.onboardingAbandoned, properties: [
                "abandoned_at_step": currentScreen.rawValue,
                "abandoned_at_screen": "\(currentScreen)"
            ])
        }

        // Reset recommendation state for fresh session
        currentMovie = nil
        currentGoodScore = 0
        recommendationError = nil
        excludedMovieIds = []
        sessionRecommendationCount = 0
        showRejectionSheet = false
        userContext = .default
        UserContext.clearDefaults()

        // Clear persisted picks
        clearSavedPicks()

        // Only clear onboarding memory on debug --reset-onboarding
        if clearMemory {
            GWOnboardingMemory.shared.clear()
        }

        // Reset multi-pick state
        recommendedPicks = []
        validMoviePool = []
        rawMoviePool = []
        pickCount = 1
        replacedPositions = []
        totalReplacements = 0
        currentProfile = nil
        currentFallbackLevel = .none
        currentTrailerKey = nil
        carouselTrailerKeys = [:]

        navigateBack(to: .landing)

        // Show Recent Picks bubble on landing if picks exist
        if !RecentPicksService.shared.getPicks().isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showRecentPicksBubble = true
                }
            }
        }
    }

    // MARK: - No Recommendation View

    private func noRecommendationView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.goldGradient)

            Text("No matches found")
                .font(GWTypography.headline())
                .foregroundColor(GWColors.white)

            Text(message)
                .font(GWTypography.body())
                .foregroundColor(GWColors.lightGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            Button {
                currentFallbackLevel = .none
                navigateBack(to: .moodSelector)
            } label: {
                Text("Try a different mood")
                    .font(GWTypography.button())
                    .foregroundColor(GWColors.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.goldGradient)
                    .cornerRadius(GWRadius.lg)
            }
            .padding(.horizontal, GWSpacing.screenPadding)

            Button {
                currentFallbackLevel = .none
                navigateBack(to: .landing)
            } label: {
                Text("Back to home")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.lightGray)
            }

            Spacer()
        }
    }

    // MARK: - Loading Overlay

    private var recommendationLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(GWColors.gold)
                    .scaleEffect(1.5)

                Text("Finding another pick...")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.lightGray)
            }
        }
    }

    // MARK: - Confidence → MainScreen Gate

    /// Only transitions from ConfidenceMoment to MainScreen when BOTH conditions are met:
    /// 1. Minimum animation time elapsed (1.2s)
    /// 2. Recommendation data is ready (loaded or errored)
    private func tryTransitionToMainScreen() {
        guard confidenceMinTimeElapsed, recommendationReady, currentScreen == .confidenceMoment else { return }
        navigateTo(.mainScreen)

        // Session restore DISABLED: no longer saving picks on transition.
        // Force quit always returns to landing screen.

        // Record recent picks for Landing screen history (with OTT deeplink data)
        if pickCount > 1 {
            for pick in recommendedPicks {
                let score = pick.composite_score > 0 ? Int(round(pick.composite_score)) : Int(round(pick.goodscore * 10))
                // Try to find matching Movie from rawMoviePool to get OTT provider info
                let matchingMovie = rawMoviePool.first { $0.id.uuidString == pick.id }
                let provider = matchingMovie?.bestMatchingProvider(for: userContext.otts)
                RecentPicksService.shared.addPick(
                    id: pick.id, title: pick.title,
                    posterPath: pick.poster_url, goodScore: score,
                    platformDisplayName: provider?.displayName,
                    deepLinkURL: provider?.deepLinkURL?.absoluteString,
                    webURL: provider?.webURL?.absoluteString,
                    year: pick.year
                )
            }
        } else if let movie = currentMovie {
            let provider = movie.bestMatchingProvider(for: userContext.otts)
            RecentPicksService.shared.addPick(
                id: movie.id.uuidString, title: movie.title,
                posterPath: movie.poster_path, goodScore: currentGoodScore,
                platformDisplayName: provider?.displayName,
                deepLinkURL: provider?.deepLinkURL?.absoluteString,
                webURL: provider?.webURL?.absoluteString,
                year: movie.year
            )
        }

        // Request notification permission AFTER user sees their first recommendation.
        // 3-second delay lets the user absorb the result before the system prompt appears.
        // If already asked or declined, this is a no-op. Gated by push_notifications flag.
        #if DEBUG
        let isScreenshotMode = UserDefaults.standard.bool(forKey: "gw_screenshot_mode")
        #else
        let isScreenshotMode = false
        #endif
        if !isScreenshotMode && GWFeatureFlags.shared.isEnabled("push_notifications") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                GWNotificationService.shared.requestPermissionIfNeeded()
            }
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ screen: Screen) {
        Crashlytics.crashlytics().log("nav: \(currentScreen) -> \(screen)")
        // Dismiss Recent Picks overlays when leaving landing
        if currentScreen == .landing && screen != .landing {
            showRecentPicksSheet = false
            showRecentPicksBubble = false
        }
        screenTransition = .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = screen
        }
    }

    private func navigateBack(to screen: Screen) {
        screenTransition = .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = screen
        }
    }

    // MARK: - Resume from Saved State

    private func resumeFromSavedState() {
        let savedStep = GWKeychainManager.shared.getOnboardingStep()

        // Only resume mid-onboarding if user quit partway through (steps 2-5).
        // If onboarding is complete (step 6+), always start fresh from landing
        // so the user sees the home screen on every app launch.
        guard savedStep > 0, savedStep < 6, UserService.shared.currentUser != nil else {
            return
        }

        #if DEBUG
        print("Resuming from saved onboarding step: \(savedStep)")
        #endif

        // Restore in-progress UserContext from UserDefaults
        if let savedContext = UserContext.loadFromDefaults() {
            self.userContext = savedContext
        }

        // Map saved step to screen (only for incomplete onboarding)
        // Steps saved by screens:
        //   MoodSelector saves step 2
        //   PlatformSelector saves step 3 -> now goes to languagePriority
        //   LanguagePriority saves step 3 (same as platform, resumes to language)
        //   DurationSelector saves step 4
        //   Step 5 was EmotionalHook (removed v1.3) — legacy compat: treat as duration complete
        switch savedStep {
        case 2:
            currentScreen = .platformSelector
        case 3:
            currentScreen = .languagePriority
        case 4, 5:
            // Duration complete (step 5 = legacy EmotionalHook, now removed)
            currentScreen = .confidenceMoment
            fetchRecommendation()
        default:
            currentScreen = .landing
        }
    }

    // MARK: - Recommendation Flow

    private func fetchRecommendation() {
        isLoadingRecommendation = true
        recommendationError = nil
        currentFallbackLevel = .none
        recommendationReady = false
        confidenceMinTimeElapsed = false
        currentTrailerKey = nil  // FIX 10: Reset trailer key for new recommendation

        // Crashlytics context — if the app crashes during recommendation, we'll know what the user selected
        Crashlytics.crashlytics().setCustomValue(userContext.mood.rawValue, forKey: "mood")
        Crashlytics.crashlytics().setCustomValue(userContext.otts.map { $0.rawValue }.joined(separator: ","), forKey: "platforms")
        Crashlytics.crashlytics().setCustomValue(userContext.languages.map { $0.rawValue }.joined(separator: ","), forKey: "languages")
        Crashlytics.crashlytics().setCustomValue("\(userContext.minDuration)-\(userContext.maxDuration)", forKey: "runtime")

        #if DEBUG
        print("[REC-START] fetchRecommendation called")
        print("   mood: \(userContext.mood.rawValue)")
        print("   platforms: \(userContext.otts.map { $0.rawValue })")
        print("   languages: \(userContext.languages.map { $0.rawValue })")
        print("   runtime: \(userContext.minDuration)-\(userContext.maxDuration)")
        print("   requiresSeries: \(userContext.requiresSeries)")
        print("   intent_tags: \(userContext.intent.intent_tags)")
        #endif

        // Guard: if critical context is missing, show error immediately
        if userContext.otts.isEmpty || userContext.languages.isEmpty {
            #if DEBUG
            print("[REC-START] ABORT: empty platforms or languages")
            #endif
            recommendationError = "Missing preferences. Please select your platforms and languages."
            isLoadingRecommendation = false
            recommendationReady = true
            tryTransitionToMainScreen()
            return
        }

        Task {
            // Ensure user exists
            // PAYWALL GATE — enable when retention data confirms value
            // Activate after 7+ days of PostHog data shows repeat usage
            // Uncomment the block below to enforce free recommendation limit
            //
            // if !GWSubscriptionManager.shared.canGetRecommendation {
            //     await MainActor.run {
            //         self.isLoadingRecommendation = false
            //         self.recommendationReady = true
            //         NotificationCenter.default.post(name: .gwShowPaywall, object: nil)
            //         self.tryTransitionToMainScreen()
            //     }
            //     return
            // }

            let userId = await AuthGuard.shared.ensureUserExistsBeforeOnboarding()

            // Set metrics user context
            MetricsService.shared.setUser(
                id: userId.uuidString,
                authType: UserService.shared.currentUser?.auth_provider ?? "anonymous",
                email: UserService.shared.currentUser?.email
            )

            // Set user for per-user tag weights and watchlist
            TagWeightStore.shared.setUser(userId.uuidString)
            WatchlistManager.shared.setUser(userId.uuidString)
            GWInteractionPoints.shared.setUser(userId.uuidString)

            // v1.3 FIX 2: Parallelize all independent async operations for speed
            let contentTypeFilter: String? = userContext.requiresSeries ? "tv" : "movie"
            let userLanguages = userContext.languages.map { $0.rawValue }

            // v1.3 FIX 2: Fire ALL independent operations in parallel including movie fetch.
            // Movie fetch doesn't depend on taste/mood/trend results, so run simultaneously.
            // Total time = max(individual ops) instead of sum(parallel batch) + fetch time.
            let tasteTask = Task { await GWTasteEngine.shared.recomputeIfNeeded(userId: userId.uuidString) }
            let moodTask = Task { await GWMoodConfigService.shared.waitForLoad(timeout: 1.5) }
            let trendTask = Task { return await GWTrendBoostService.shared.fetchActiveTrendBoosts() }
            let histTask = Task { return await self.fetchHistoricalExclusions(userId: userId) }
            let maturityTask = Task { return await InteractionService.shared.getUserMaturityInfo(userId: userId) }
            let movieTask = Task { try await SupabaseService.shared.fetchMoviesForAvailabilityCheck(
                languages: userLanguages,
                contentType: contentTypeFilter,
                acceptCount: 0,
                limit: 1000
            ) }
            let intlMovieTask = Task { try await SupabaseService.shared.fetchMovies(limit: 500) }

            // Await all parallel results (total time = max of individual ops, not sum)
            await tasteTask.value
            await moodTask.value
            let trendBoostsByTmdbId = await trendTask.value
            let historicalExclusions = await histTask.value
            let maturityInfo = await maturityTask.value
            let allExcludedIds = excludedMovieIds.union(historicalExclusions)

            // Build profile from context — uses combined session + historical exclusions
            let profile = GWUserProfileComplete.from(
                context: userContext,
                userId: userId.uuidString,
                excludedIds: allExcludedIds.map { $0.uuidString }
            )
            let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

            // Await movie fetch (already running in parallel since launch)
            do {
                let movies = try await movieTask.value

                #if DEBUG
                print("[REC] RECOMMENDATION DEBUG:")
                print("   Fetched \(movies.count) movies from Supabase (contentType filter: \(contentTypeFilter ?? "none"))")
                print("   User mood: \(userContext.mood.rawValue)")
                print("   Intent tags: \(userContext.intent.intent_tags)")
                print("   Platforms: \(userContext.otts.map { $0.rawValue })")
                print("   Languages: \(userLanguages)")
                print("   Runtime: \(userContext.minDuration)-\(userContext.maxDuration) min")
                print("   RequiresSeries: \(userContext.requiresSeries)")
                // Log content_type distribution
                let contentTypes = Dictionary(grouping: movies, by: { $0.content_type ?? "NULL" })
                for (ct, movs) in contentTypes {
                    print("   content_type='\(ct)': \(movs.count) movies")
                }
                // Log first 5 movies fetched
                for (i, m) in movies.prefix(5).enumerated() {
                    let gwm = GWMovie(from: m)
                    print("   Top[\(i)]: \(m.title) | content_type=\(m.content_type ?? "nil") | tags=\(gwm.tags) | goodscore=\(gwm.goodscore) | composite=\(gwm.composite_score)")
                }
                #endif

                // DIAGNOSTIC: Log validation failures for first 10 movies to find the blocking rule
                let diagGwMovies = movies.prefix(10).map { GWMovie(from: $0) }
                var failureCounts: [String: Int] = [:]
                for gwm in diagGwMovies {
                    let result = engine.isValidMovie(gwm, profile: profile)
                    if case .invalid(let failure) = result {
                        let key = failure.ruleLabel
                        failureCounts[key, default: 0] += 1
                    }
                }
                // Also check ALL movies for failure distribution
                let allGwMovies = movies.map { GWMovie(from: $0) }
                var allFailureCounts: [String: Int] = [:]
                var validCount = 0
                for gwm in allGwMovies {
                    let result = engine.isValidMovie(gwm, profile: profile)
                    switch result {
                    case .valid: validCount += 1
                    case .invalid(let failure): allFailureCounts[failure.ruleLabel, default: 0] += 1
                    }
                }
                #if DEBUG
                print("[DIAG] DIAGNOSTIC: \(movies.count) movies fetched, \(validCount) valid")
                print("[DIAG] Failure breakdown: \(allFailureCounts)")
                print("[DIAG] Profile: platforms=\(profile.platforms), langs=\(profile.preferredLanguages), runtime=\(profile.runtimeWindow.min)-\(profile.runtimeWindow.max), intentTags=\(profile.intentTags)")
                #endif

                // Always start with 5 cards — rejections narrow the carousel, not interaction points
                let effectivePickCount = 5

                #if DEBUG
                print("[CAROUSEL] === Carousel Debug ===")
                print("[CAROUSEL] User ID: \(userId.uuidString)")
                print("[CAROUSEL] Interaction Points: \(GWInteractionPoints.shared.currentPoints)")
                print("[CAROUSEL] Effective Pick Count: \(effectivePickCount)")
                print("[CAROUSEL] ========================")
                #endif

                // Filter out standup specials and movies without poster (prevents blank cards)
                let moviesWithPoster = movies.filter {
                    ($0.poster_path != nil && !($0.poster_path ?? "").isEmpty)
                    && ($0.is_standup != true)  // DB flag safety net
                }

                // Cache the movie pool for replacement logic
                // Apply content filter + suppression filter (Task 1c)
                let gwMoviePool = moviesWithPoster
                    .map { GWMovie(from: $0) }
                    .filter { !contentFilter.shouldExclude(movie: $0) }
                    .filter { !GWSuppressionManager.shared.isSuppressed(movieId: UUID(uuidString: $0.id) ?? UUID()) }

                // Task 1d: Check if pool is running low after suppression
                if gwMoviePool.count < 5 && !GWSuppressionManager.shared.suppressionLifted {
                    await MainActor.run {
                        showSuppressionExhaustedPopup = true
                    }
                    PostHogSDK.shared.capture("suppression_pool_exhausted", properties: [
                        "user_id": userId.uuidString
                    ])
                }

                // Task 3: Cold start pool override for new users
                // When isNewUser is true, build/use a curated high-quality pool
                let effectivePool: [GWMovie]
                if GWSubscriptionManager.shared.isNewUser {
                    if !GWColdStartService.shared.hasValidPool {
                        GWColdStartService.shared.buildPool(
                            from: movies,
                            platforms: userContext.otts.map { $0.rawValue },
                            languages: userContext.languages.map { $0.rawValue },
                            mood: userContext.mood.rawValue,
                            minDuration: userContext.minDuration,
                            maxDuration: userContext.maxDuration
                        )
                    }
                    let coldPool = GWColdStartService.shared.cachedPool
                        .filter { !GWSuppressionManager.shared.isSuppressed(movieId: UUID(uuidString: $0.id) ?? UUID()) }
                    // Use cold start pool if it has movies, otherwise fall through to general pool
                    effectivePool = coldPool.isEmpty ? gwMoviePool : coldPool
                    #if DEBUG
                    print("[ColdStart] Using cold start pool: \(effectivePool.count) movies (general pool: \(gwMoviePool.count))")
                    #endif
                } else {
                    effectivePool = gwMoviePool
                }

                // Build UUID-keyed trend boost lookup and set on engine (INV-T01/T03)
                let resolvedTrendBoosts = GWTrendBoostService.shared.buildUUIDLookup(
                    trendBoosts: trendBoostsByTmdbId,
                    movies: movies
                )
                engine.activeTrendBoosts = resolvedTrendBoosts

                // Compute international pick (dubbed content — INV-L09)
                // Uses ALL fetched movies (not just language-filtered) to find dubbed content
                let allMoviesForIntl = try await intlMovieTask.value
                let allGwForIntl = allMoviesForIntl.map { GWMovie(from: $0) }.filter { !contentFilter.shouldExclude(movie: $0) }
                // Compute main pool top score for ceiling calculation
                let mainPoolScores = effectivePool.map { engine.computeScore(movie: $0, profile: profile) }
                let mainPoolTopScore = mainPoolScores.max() ?? 0.0
                let intlOutput = engine.recommendInternationalPick(
                    from: allGwForIntl,
                    profile: profile,
                    mainPoolTopScore: mainPoolTopScore
                )
                let resolvedIntlPick = intlOutput.movie

                #if DEBUG
                print("   gwMoviePool count (after content filter): \(gwMoviePool.count)")
                if let intl = resolvedIntlPick {
                    print("   [INTL] International Pick: \(intl.title) (lang=\(intl.language), dubbed=\(intl.dubbedLanguages))")
                } else {
                    print("   [INTL] No international pick available")
                }
                #endif

                // Use multi-pick when pickCount > 1
                if effectivePickCount > 1 {
                    var picks = engine.recommendMultiple(
                        from: effectivePool,
                        profile: profile,
                        count: effectivePickCount
                    )

                    #if DEBUG
                    print("MULTI-PICK: \(effectivePickCount) picks requested, \(picks.count) returned")
                    for (i, pick) in picks.enumerated() {
                        print("   Pick[\(i)]: \(pick.title) | tags=\(pick.tags) | score=\(engine.computeScore(movie: pick, profile: profile))")
                    }
                    #endif

                    // Fallback: if multi-pick returned fewer than requested,
                    // fill from top-scored VALID movies so carousel always shows
                    if picks.count < effectivePickCount {
                        let existingIds = Set(picks.map { $0.id })
                        // Fallback pool must pass isValidMovie (tiered gates, year floor, etc.)
                        var fallbackPool = effectivePool.filter { movie in
                            guard !existingIds.contains(movie.id) else { return false }
                            if case .valid = engine.isValidMovie(movie, profile: profile) { return true }
                            return false
                        }
                        if fallbackPool.count + picks.count < effectivePickCount {
                            // Wider pool but still validated
                            let widerPool = movies.map { GWMovie(from: $0) }.filter { movie in
                                guard !existingIds.contains(movie.id) else { return false }
                                if case .valid = engine.isValidMovie(movie, profile: profile) { return true }
                                return false
                            }
                            fallbackPool = widerPool
                        }
                        let scored = fallbackPool.sorted {
                            engine.computeScore(movie: $0, profile: profile) >
                            engine.computeScore(movie: $1, profile: profile)
                        }
                        let needed = effectivePickCount - picks.count
                        picks.append(contentsOf: scored.prefix(needed))
                        #if DEBUG
                        print("[CAROUSEL] Fallback filled: \(picks.count) total picks (all validated)")
                        #endif
                    }

                    // If recommendMultiple + fallback returned empty, use recommendWithFallback
                    // to get at least one pick, then fill remaining carousel slots
                    if picks.isEmpty {
                        #if DEBUG
                        print("[CAROUSEL] recommendMultiple returned empty, using recommendWithFallback to seed carousel")
                        #endif
                        let (fallbackOutput, _, _) = engine.recommendWithFallback(
                            fromRawMovies: movies,
                            profile: profile,
                            contentFilter: contentFilter
                        )
                        if let seedMovie = fallbackOutput.movie {
                            picks = [seedMovie]
                            // Fill remaining slots from scored pool (relaxed: skip isValidMovie for fill,
                            // but still filter basic language/platform/poster/standup)
                            let seedIds = Set(picks.map { $0.id })
                            let fillPool = effectivePool
                                .filter { !seedIds.contains($0.id) }
                                .sorted { engine.computeScore(movie: $0, profile: profile) > engine.computeScore(movie: $1, profile: profile) }
                            let needed = effectivePickCount - picks.count
                            picks.append(contentsOf: fillPool.prefix(needed))
                            #if DEBUG
                            print("[CAROUSEL] Seeded carousel: \(picks.count) picks (1 from fallback + \(picks.count - 1) from pool)")
                            #endif
                        }
                    }

                    if !picks.isEmpty {
                        await MainActor.run {
                            self.recommendedPicks = picks
                            self.rawMoviePool = movies
                            self.validMoviePool = effectivePool
                            self.pickCount = picks.count  // Use actual count, not effectivePickCount
                            self.replacedPositions = []
                            self.totalReplacements = 0
                            self.currentProfile = profile
                            self.internationalPick = resolvedIntlPick
                            self.trendBoostsByUUID = resolvedTrendBoosts
                            self.currentTrendTag = resolvedTrendBoosts[picks[0].id]?.relevance_tag
                            self.isLoadingRecommendation = false
                            self.sessionRecommendationCount += 1
                            self.recommendationShownTime = Date()

                            // Set currentMovie to first pick for enjoy screen compatibility
                            if let firstRaw = movies.first(where: { $0.id.uuidString == picks[0].id }) {
                                self.assignCurrentMovie(firstRaw, fallbackPool: movies)
                                self.currentGoodScore = picks[0].composite_score > 0 ? Int(round(picks[0].composite_score)) : Int(round(picks[0].goodscore * 10))
                            }

                            // Track metrics
                            MetricsService.shared.track(.pickShown, properties: [
                                "pick_count": picks.count,
                                "picks_returned": picks.count,
                                "recommendation_number": self.sessionRecommendationCount,
                                "mode": "multi_pick"
                            ])

                            MetricsService.shared.track(.recommendationShown, properties: [
                                "pick_count": picks.count,
                                "mode": "multi_pick"
                            ])

                            // Record shown for all picks
                            Task {
                                for pick in picks {
                                    if let movieUUID = UUID(uuidString: pick.id) {
                                        try? await InteractionService.shared.recordShown(
                                            userId: userId,
                                            movieId: movieUUID
                                        )
                                    }
                                }
                            }

                            // Fetch trailer keys for all carousel picks in parallel (FIX 10)
                            self.carouselTrailerKeys = [:]
                            Task {
                                for pick in picks {
                                    if let rawMovie = movies.first(where: { $0.id.uuidString == pick.id }),
                                       let tmdbId = rawMovie.tmdb_id {
                                        Task {
                                            if let key = await TrailerService.fetchTrailerKey(tmdbId: tmdbId) {
                                                await MainActor.run {
                                                    self.carouselTrailerKeys[pick.id] = key
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            GWKeychainManager.shared.completeOnboarding()
                            // FIX 1: Save onboarding memory for 30-day skip
                            GWOnboardingMemory.shared.save(
                                otts: self.userContext.otts,
                                languages: self.userContext.languages,
                                minDuration: self.userContext.minDuration,
                                maxDuration: self.userContext.maxDuration,
                                requiresSeries: self.userContext.requiresSeries
                            )
                            UserContext.clearDefaults()
                            GWNotificationService.shared.saveLastMood(self.userContext.mood.rawValue)

                            if self.sessionRecommendationCount == 1 {
                                MetricsService.shared.track(.onboardingComplete)
                            }

                            GWSubscriptionManager.shared.incrementRecommendationCount(wasAccepted: false)
                            self.recommendationReady = true
                            self.tryTransitionToMainScreen()
                        }
                        return
                    }
                    // If STILL empty (no movies at all), fall through to single pick
                }

                // Use canonical engine with production fallback
                let (output, fallbackLevel, _) = engine.recommendWithFallback(
                    fromRawMovies: movies,
                    profile: profile,
                    contentFilter: contentFilter
                )

                #if DEBUG
                if fallbackLevel != .none {
                    print("[WARN] Used fallback level \(fallbackLevel.rawValue) to find recommendation")
                }
                #endif

                #if DEBUG
                if let gwMovie = output.movie {
                    let rawMovie = movies.first(where: { $0.id.uuidString == gwMovie.id })
                    print("   [OK] RECOMMENDED: \(gwMovie.title)")
                    print("      content_type: \(rawMovie?.content_type ?? "nil")")
                    print("      tags: \(gwMovie.tags)")
                    print("      goodscore: \(gwMovie.goodscore), composite: \(gwMovie.composite_score)")
                    print("      score: \(engine.computeScore(movie: gwMovie, profile: profile))")
                    let intentTags = Set(profile.intentTags)
                    let movieTags = Set(gwMovie.tags)
                    print("      tag intersection: \(movieTags.intersection(intentTags))")
                } else {
                    print("   [FAIL] NO RECOMMENDATION: \(output.stopCondition?.description ?? "unknown")")
                }
                #endif

                #if DEBUG
                // Screenshot mode: if we wanted carousel but multi-pick failed,
                // use single-pick results to build a fake carousel from top movies
                if effectivePickCount > 1 && UserDefaults.standard.bool(forKey: "gw_screenshot_mode"),
                   let mainPick = output.movie {
                    print("[SCREENSHOT] Building carousel from single-pick + top movies")
                    var carouselPicks = [mainPick]
                    let allGW = movies.map { GWMovie(from: $0) }
                    let sorted = allGW
                        .filter { $0.id != mainPick.id }
                        .sorted { ($0.composite_score > 0 ? $0.composite_score : $0.goodscore * 10) > ($1.composite_score > 0 ? $1.composite_score : $1.goodscore * 10) }
                    carouselPicks.append(contentsOf: sorted.prefix(effectivePickCount - 1))
                    print("[SCREENSHOT] Carousel built: \(carouselPicks.count) picks")

                    if carouselPicks.count > 1 {
                        await MainActor.run {
                            self.recommendedPicks = carouselPicks
                            self.rawMoviePool = movies
                            self.validMoviePool = effectivePool
                            self.pickCount = carouselPicks.count
                            self.replacedPositions = []
                            self.totalReplacements = 0
                            self.currentProfile = profile
                            self.isLoadingRecommendation = false
                            self.sessionRecommendationCount += 1
                            self.recommendationShownTime = Date()
                            if let firstRaw = movies.first(where: { $0.id.uuidString == carouselPicks[0].id }) {
                                self.assignCurrentMovie(firstRaw, fallbackPool: movies)
                                self.currentGoodScore = carouselPicks[0].composite_score > 0 ? Int(round(carouselPicks[0].composite_score)) : Int(round(carouselPicks[0].goodscore * 10))
                            }
                            GWKeychainManager.shared.completeOnboarding()
                            self.recommendationReady = true
                            self.tryTransitionToMainScreen()
                        }
                        return
                    }
                }

                // Screenshot mode: if single-pick engine returned nil, use best raw movie
                if output.movie == nil && UserDefaults.standard.bool(forKey: "gw_screenshot_mode") {
                    let allGW = movies.map { GWMovie(from: $0) }
                    let best = allGW
                        .sorted { ($0.composite_score > 0 ? $0.composite_score : $0.goodscore * 10) > ($1.composite_score > 0 ? $1.composite_score : $1.goodscore * 10) }
                        .first
                    if let pick = best {
                        print("[SCREENSHOT] Single-pick fallback: \(pick.title)")
                        await MainActor.run {
                            if let rawMovie = movies.first(where: { $0.id.uuidString == pick.id }) {
                                self.assignCurrentMovie(rawMovie, fallbackPool: movies)
                                self.currentGoodScore = pick.composite_score > 0 ? Int(round(pick.composite_score)) : Int(round(pick.goodscore * 10))
                            }
                            self.sessionRecommendationCount += 1
                            self.isLoadingRecommendation = false
                            self.recommendationShownTime = Date()
                            self.pickCount = 1
                            GWKeychainManager.shared.completeOnboarding()
                            self.recommendationReady = true
                            self.tryTransitionToMainScreen()
                        }
                        return
                    }
                }
                #endif

                await MainActor.run {
                    if let gwMovie = output.movie,
                       let movie = movies.first(where: { $0.id.uuidString == gwMovie.id }) {
                        self.assignCurrentMovie(movie, fallbackPool: movies)
                        self.currentGoodScore = gwMovie.composite_score > 0 ? Int(round(gwMovie.composite_score)) : Int(round(gwMovie.goodscore * 10))
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false
                        self.recommendationShownTime = Date()  // Start decision timer
                        self.pickCount = 1  // Ensure single-pick mode routing
                        self.currentFallbackLevel = fallbackLevel
                        self.internationalPick = resolvedIntlPick
                        self.trendBoostsByUUID = resolvedTrendBoosts
                        self.currentTrendTag = resolvedTrendBoosts[gwMovie.id]?.relevance_tag

                        // Fetch trailer key in background (FIX 10)
                        if let tmdbId = movie.tmdb_id {
                            Task {
                                let key = await TrailerService.fetchTrailerKey(tmdbId: tmdbId)
                                await MainActor.run { self.currentTrailerKey = key }
                            }
                        }

                        // Track metrics
                        MetricsService.shared.track(.pickShown, properties: [
                            "movie_id": movie.id.uuidString,
                            "movie_title": movie.title,
                            "good_score": self.currentGoodScore,
                            "recommendation_number": self.sessionRecommendationCount
                        ])

                        // Track recommendation shown for dashboard funnel
                        MetricsService.shared.track(.recommendationShown, properties: [
                            "movie_id": movie.id.uuidString,
                            "good_score": self.currentGoodScore,
                            "fallback_level": fallbackLevel.rawValue
                        ])

                        // Record shown interaction
                        Task {
                            try? await InteractionService.shared.recordShown(
                                userId: userId,
                                movieId: movie.id
                            )
                        }

                        // Mark onboarding as complete
                        GWKeychainManager.shared.completeOnboarding()
                        // FIX 1: Save onboarding memory for 30-day skip
                        GWOnboardingMemory.shared.save(
                            otts: self.userContext.otts,
                            languages: self.userContext.languages,
                            minDuration: self.userContext.minDuration,
                            maxDuration: self.userContext.maxDuration,
                            requiresSeries: self.userContext.requiresSeries
                        )
                        UserContext.clearDefaults()

                        // Save mood for personalized weekend notifications
                        GWNotificationService.shared.saveLastMood(self.userContext.mood.rawValue)

                        if self.sessionRecommendationCount == 1 {
                            MetricsService.shared.track(.onboardingComplete)
                            MetricsService.shared.track(.firstRecommendation, properties: [
                                "movie_title": movie.title
                            ])
                        }

                        // Signal recommendation ready for ConfidenceMoment transition
                        GWSubscriptionManager.shared.incrementRecommendationCount(wasAccepted: false)
                        self.recommendationReady = true
                        self.tryTransitionToMainScreen()
                    } else {
                        self.currentMovie = nil
                        self.isLoadingRecommendation = false

                        if let stopCondition = output.stopCondition {
                            self.recommendationError = stopConditionMessage(stopCondition)
                        } else {
                            self.recommendationError = "No match found for these preferences. Try adjusting platforms or language."
                        }

                        #if DEBUG
                        if let sc = output.stopCondition {
                            print("No recommendation: \(sc.description)")
                        }
                        #endif

                        // Even on error, transition so user can see the error message
                        self.recommendationReady = true
                        self.tryTransitionToMainScreen()
                    }
                }
            } catch {
                Crashlytics.crashlytics().record(error: error)
                await MainActor.run {
                    self.isLoadingRecommendation = false
                    self.recommendationError = "Something went wrong. Please check your connection and try again."

                    #if DEBUG
                    print("Recommendation fetch error: \(error)")
                    #endif

                    // Transition on error too
                    self.recommendationReady = true
                    self.tryTransitionToMainScreen()
                }
            }
        }
    }

    private func fetchNextRecommendation(afterRejection rejectedMovieId: UUID, reason: String?) {
        isLoadingRecommendation = true
        recommendationError = nil

        // Add rejected movie to exclusions
        excludedMovieIds.insert(rejectedMovieId)

        Task {
            guard let userId = AuthGuard.shared.currentUserId else {
                await MainActor.run {
                    isLoadingRecommendation = false
                    recommendationError = "No user session. Please restart the app."
                }
                return
            }

            do {
                // Fetch shown/rejected history from Supabase to avoid cross-session repeats
                let historicalExclusions = await fetchHistoricalExclusions(userId: userId)
                let allExcludedIds = excludedMovieIds.union(historicalExclusions)

                // Build profile from ACTUAL user context (preserves real intent tags)
                // Uses combined session + historical exclusions
                let profile = GWUserProfileComplete.from(
                    context: userContext,
                    userId: userId.uuidString,
                    excludedIds: allExcludedIds.map { $0.uuidString }
                )

                // Get user maturity info for content filtering
                let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userId)
                let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

                // Fetch movies with content type filter
                let contentTypeFilter: String? = userContext.requiresSeries ? "tv" : "movie"
                let userLanguages = userContext.languages.map { $0.rawValue }

                let movies = try await SupabaseService.shared.fetchMoviesForAvailabilityCheck(
                    languages: userLanguages,
                    contentType: contentTypeFilter,
                    acceptCount: 0,
                    limit: 1000
                )

                // Get rejected movie for Section 7 "not tonight" logic
                let rejectedMovie = movies.first(where: { $0.id == rejectedMovieId })
                let gwMovies = movies.map { GWMovie(from: $0) }.filter { !contentFilter.shouldExclude(movie: $0) }

                let output: GWRecommendationOutput
                if let rejected = rejectedMovie {
                    // Use Section 7: avoid similar tags to rejected movie
                    let gwRejected = GWMovie(from: rejected)
                    output = engine.recommendAfterNotTonight(
                        from: gwMovies,
                        profile: profile,
                        rejectedMovie: gwRejected
                    )
                } else {
                    // Rejected movie not in cache — fall back to regular recommendation with fallback
                    let (fallbackOutput, _, _) = engine.recommendWithFallback(from: gwMovies, profile: profile)
                    output = fallbackOutput
                }

                #if DEBUG
                if let gwMovie = output.movie {
                    print("[REC] RETRY RECOMMENDATION: \(gwMovie.title)")
                    print("   tags: \(gwMovie.tags), intent: \(profile.intentTags)")
                    print("   score: \(engine.computeScore(movie: gwMovie, profile: profile))")
                } else {
                    print("[REC] RETRY: No recommendation -- \(output.stopCondition?.description ?? "unknown")")
                }
                #endif

                await MainActor.run {
                    if let gwMovie = output.movie,
                       let movie = movies.first(where: { $0.id.uuidString == gwMovie.id }) {
                        self.assignCurrentMovie(movie, fallbackPool: movies)
                        self.currentGoodScore = gwMovie.composite_score > 0 ? Int(round(gwMovie.composite_score)) : Int(round(gwMovie.goodscore * 10))
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false
                        self.recommendationShownTime = Date()  // Start decision timer

                        // Track metrics
                        MetricsService.shared.track(.pickShown, properties: [
                            "movie_id": movie.id.uuidString,
                            "movie_title": movie.title,
                            "good_score": self.currentGoodScore,
                            "recommendation_number": self.sessionRecommendationCount,
                            "is_retry": true
                        ])

                        // Record shown
                        Task {
                            try? await InteractionService.shared.recordShown(
                                userId: userId,
                                movieId: movie.id
                            )
                        }
                    } else {
                        self.currentMovie = nil
                        self.isLoadingRecommendation = false
                        self.recommendationError = "We've shown all the top picks for tonight. Try adjusting the mood or platforms."
                    }
                }
            } catch {
                Crashlytics.crashlytics().record(error: error)
                await MainActor.run {
                    self.isLoadingRecommendation = false
                    self.recommendationError = "Something went wrong finding another pick. Please try again."

                    #if DEBUG
                    print("Next recommendation error: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Interaction Handlers

    private func handleWatchNow(movie: Movie, provider: OTTProvider) {
        guard let userId = AuthGuard.shared.currentUserId else { return }

        // Fix 1d: Mark as shown in session gate
        sessionShownIds.insert(movie.id)

        // Task 7: Record accept for session summary
        GWJourneyTracker.shared.recordAccept()

        // Add interaction points for single-pick watch_now
        GWInteractionPoints.shared.add(3)

        // Record decision timing (threshold-gated: always collected, used after ≥20 samples)
        if let shownTime = recommendationShownTime {
            let decisionSeconds = Date().timeIntervalSince(shownTime)
            InteractionService.shared.recordDecisionTiming(
                userId: userId,
                movieId: movie.id,
                decisionSeconds: decisionSeconds,
                wasAccepted: true
            )
        }

        // Track metrics
        MetricsService.shared.track(.watchNow, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "platform": provider.displayName,
            "good_score": currentGoodScore,
            "recommendation_number": sessionRecommendationCount
        ])

        // Track recommendation accepted for dashboard funnel
        MetricsService.shared.track(.recommendationAccepted, properties: [
            "movie_id": movie.id.uuidString,
            "platform": provider.displayName,
            "good_score": currentGoodScore
        ])

        // Record interaction
        Task {
            // Task 1c: Mark as watched in suppression cache (sync first, then Supabase)
            await GWSuppressionManager.shared.markWatched(movieId: movie.id, userId: userId.uuidString)

            // Record watch_now with platform bias tracking
            try? await InteractionService.shared.recordAcceptanceWithBias(
                userId: userId,
                movieId: movie.id,
                platforms: [provider.displayName]
            )

            // Schedule post-watch feedback
            GWFeedbackEnforcer.shared.schedulePostWatchFeedback(
                movieId: movie.id.uuidString,
                movieTitle: movie.title,
                userId: userId.uuidString
            )

            // Task 6a: Add to pending ratings for "How was it?" banner on next session
            let gwMovieForRating = GWMovie(from: movie)
            GWRatingService.shared.addPendingRating(
                movieId: movie.id.uuidString,
                movieTitle: movie.title,
                posterPath: movie.poster_path,
                movieTags: gwMovieForRating.tags
            )

            // Update tag weights (positive signal)
            let gwMovie = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: .watch_now
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Navigate to enjoy screen after a short delay (lets OTT app open first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateTo(.enjoyScreen)
        }
    }

    private func handleAlreadySeen(movie: Movie) {
        // Fix 1d: Mark as shown in session gate
        sessionShownIds.insert(movie.id)

        let rejectedId = movie.id

        // Pattern A: Keep old movie visible during async fetch — no blank frame.
        // currentMovie stays non-nil until assignCurrentMovie replaces it atomically.
        isLoadingNextMovie = true
        showNoMoreMatches = false

        // Add interaction points for already_seen
        GWInteractionPoints.shared.add(1)

        // Track metrics
        MetricsService.shared.track(.rejectHard, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "reason": "already_seen",
            "recommendation_number": sessionRecommendationCount
        ])

        // Track recommendation already seen for dashboard
        MetricsService.shared.track(.recommendationAlreadySeen, properties: [
            "movie_id": movie.id.uuidString
        ])

        // Record interaction (if authenticated)
        if let userId = AuthGuard.shared.currentUserId {
            Task {
                // Task 1c: Mark as rejected in suppression cache
                await GWSuppressionManager.shared.markRejected(movieId: movie.id, userId: userId.uuidString)

                try? await InteractionService.shared.recordAlreadySeen(
                    userId: userId,
                    movieId: movie.id
                )
            }
        }

        // Always fetch next similar movie
        fetchNextAfterAlreadySeen(movieId: rejectedId)
    }

    private func handleRejectionWithReason(_ reason: RejectionSheetView.RejectionReason) {
        guard let movie = currentMovie else { return }
        guard let userId = AuthGuard.shared.currentUserId else { return }

        // Fix 1d: Mark as shown in session gate
        sessionShownIds.insert(movie.id)

        let rejectedId = movie.id

        // Pattern A: Keep old movie visible during async fetch — no blank frame.
        // currentMovie stays non-nil until fetchNextRecommendation replaces it atomically.
        isLoadingNextMovie = true
        showNoMoreMatches = false

        // Task 7: Record reject for session summary
        GWJourneyTracker.shared.recordReject()

        // Add interaction points for not_tonight
        GWInteractionPoints.shared.add(2)

        // Record decision timing (threshold-gated: always collected, used after ≥20 samples)
        if let shownTime = recommendationShownTime {
            let decisionSeconds = Date().timeIntervalSince(shownTime)
            InteractionService.shared.recordDecisionTiming(
                userId: userId,
                movieId: movie.id,
                decisionSeconds: decisionSeconds,
                wasAccepted: false
            )
        }

        // Close sheet
        withAnimation(.easeOut(duration: 0.25)) {
            showRejectionSheet = false
        }

        // Track metrics
        MetricsService.shared.track(.retrySoft, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "reason": reason.rawValue,
            "recommendation_number": sessionRecommendationCount
        ])

        // Track recommendation rejected for dashboard funnel
        MetricsService.shared.track(.recommendationRejected, properties: [
            "movie_id": movie.id.uuidString,
            "reason": reason.rawValue
        ])

        // Record interaction with learning signal
        // BUG FIX: Pass the MOVIE's platforms, not all user platforms
        // Previously this corrupted platform bias by penalizing unrelated platforms
        Task {
            // Task 1c: Mark as rejected in suppression cache
            await GWSuppressionManager.shared.markRejected(movieId: movie.id, userId: userId.uuidString)

            try? await InteractionService.shared.recordRejectionWithLearning(
                userId: userId,
                movieId: movie.id,
                rejectionReason: reason.rawValue,
                platforms: movie.platformNames
            )

            // feedForward: Update tag weights BEFORE next recommendation in same session (INV-E04).
            // Negative signal applied immediately so next pick reflects rejection.
            let gwMovie = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: .not_tonight
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Fetch next recommendation (uses feedForward tag weights from above)
        fetchNextRecommendation(afterRejection: rejectedId, reason: reason.rawValue)
    }

    private func handleShowAnother() {
        guard let movie = currentMovie else { return }
        guard let userId = AuthGuard.shared.currentUserId else { return }

        // Fix 1d: Mark as shown in session gate
        sessionShownIds.insert(movie.id)

        let rejectedId = movie.id

        // Fix 3: Replacement count with maturity threshold
        let interactionCount = GWSubscriptionManager.shared.cachedInteractionCount
        let isMature = interactionCount >= 80
        let maxSessionReplacements = isMature ? Int.max : 5
        if sessionReplacementCount > 0 && sessionReplacementCount >= maxSessionReplacements {
            showReplacementLimitMessage = true
            return
        }
        sessionReplacementCount += 1

        // Add interaction points for show_me_another
        GWInteractionPoints.shared.add(1)

        // Record decision timing (threshold-gated: always collected, used after ≥20 samples)
        if let shownTime = recommendationShownTime {
            let decisionSeconds = Date().timeIntervalSince(shownTime)
            InteractionService.shared.recordDecisionTiming(
                userId: userId,
                movieId: movie.id,
                decisionSeconds: decisionSeconds,
                wasAccepted: false
            )
        }

        // Close sheet
        withAnimation(.easeOut(duration: 0.25)) {
            showRejectionSheet = false
        }

        // Track metrics
        MetricsService.shared.track(.retrySoft, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "reason": "show_another",
            "recommendation_number": sessionRecommendationCount
        ])

        // Record as not_tonight with no specific reason
        Task {
            // Task 1c: Mark as rejected in suppression cache
            await GWSuppressionManager.shared.markRejected(movieId: movie.id, userId: userId.uuidString)

            try? await InteractionService.shared.recordNotTonight(
                userId: userId,
                movieId: movie.id,
                reason: "show_another"
            )

            // feedForward: Update tag weights BEFORE next recommendation in same session (INV-E04).
            // Weak tag weight signal: "show me another" = very mild negative
            // User didn't actively reject, but wasn't excited enough to watch
            // Threshold-gated: always collected, but delta is tiny (-0.05) so it only
            // matters after many interactions accumulate.
            // sessionLearning: weights persist to UserDefaults immediately so the next
            // recommendation picks them up via TagWeightStore.shared.getWeights()
            let gwMovie = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: .show_me_another
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Fetch next recommendation (uses feedForward tag weights from above)
        fetchNextRecommendation(afterRejection: rejectedId, reason: nil)
    }

    // MARK: - Multi-Pick Interaction Handlers

    private func handleMultiPickWatchNow(movie: Movie, provider: OTTProvider) {
        guard let userId = AuthGuard.shared.currentUserId else { return }

        // Fix 1d: Mark as shown in session gate
        sessionShownIds.insert(movie.id)

        // Record decision timing
        if let shownTime = recommendationShownTime {
            let decisionSeconds = Date().timeIntervalSince(shownTime)
            InteractionService.shared.recordDecisionTiming(
                userId: userId,
                movieId: movie.id,
                decisionSeconds: decisionSeconds,
                wasAccepted: true
            )
        }

        // Add interaction points for watch_now
        GWInteractionPoints.shared.add(3)

        // Track metrics
        MetricsService.shared.track(.watchNow, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "platform": provider.displayName,
            "good_score": currentGoodScore,
            "recommendation_number": sessionRecommendationCount,
            "mode": "multi_pick",
            "pick_count": pickCount
        ])

        MetricsService.shared.track(.recommendationAccepted, properties: [
            "movie_id": movie.id.uuidString,
            "platform": provider.displayName,
            "mode": "multi_pick"
        ])

        // Record acceptance + tag weights for chosen movie
        Task {
            try? await InteractionService.shared.recordAcceptanceWithBias(
                userId: userId,
                movieId: movie.id,
                platforms: [provider.displayName]
            )

            GWFeedbackEnforcer.shared.schedulePostWatchFeedback(
                movieId: movie.id.uuidString,
                movieTitle: movie.title,
                userId: userId.uuidString
            )

            let gwChosen = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwChosen,
                action: .watch_now
            )
            TagWeightStore.shared.saveWeights(updatedWeights)

            // Implicit skip for all non-chosen cards (gated by feature flag)
            if GWFeatureFlags.shared.isEnabled("implicit_skip_tracking") {
                let chosenId = movie.id.uuidString
                let nonChosen = recommendedPicks.filter { $0.id != chosenId }
                for skippedMovie in nonChosen {
                    // Record implicit_skip interaction
                    if let movieUUID = UUID(uuidString: skippedMovie.id) {
                        try? await InteractionService.shared.recordInteraction(
                            userId: userId,
                            movieId: movieUUID,
                            action: .implicit_skip
                        )
                    }

                    // Implicit skip tag weight update (-0.05)
                    let skippedWeights = updateTagWeights(
                        tagWeights: TagWeightStore.shared.getWeights(),
                        movie: skippedMovie,
                        action: .implicit_skip
                    )
                    TagWeightStore.shared.saveWeights(skippedWeights)

                    // Add 1 point per implicit skip
                    GWInteractionPoints.shared.add(1)
                }
            }
        }

        // Set currentMovie for enjoy screen
        currentMovie = movie
        let gwMovie = GWMovie(from: movie)
        currentGoodScore = gwMovie.composite_score > 0 ? Int(round(gwMovie.composite_score)) : Int(round(gwMovie.goodscore * 10))

        // Navigate to enjoy screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateTo(.enjoyScreen)
        }
    }

    private let maxReplacements = 5  // Hard cap: 5 replacements per carousel session

    private func handleCardRejection(gwMovie: GWMovie, reason: GWCardRejectionReason) {
        guard let userId = AuthGuard.shared.currentUserId else { return }
        guard let profile = currentProfile else { return }

        // Find position of rejected card
        guard let position = recommendedPicks.firstIndex(where: { $0.id == gwMovie.id }) else { return }

        // Add interaction points based on reason
        switch reason {
        case .notInterested:
            GWInteractionPoints.shared.add(2)
        case .alreadySeen:
            GWInteractionPoints.shared.add(1)
        }

        // Record interaction
        let interactionAction: InteractionAction = reason == .notInterested ? .not_interested : .already_seen_card
        Task {
            if let movieUUID = UUID(uuidString: gwMovie.id) {
                try? await InteractionService.shared.recordInteraction(
                    userId: userId,
                    movieId: movieUUID,
                    action: interactionAction
                )
            }

            // Update tag weights based on reason
            let specAction: GWSpecInteraction.SpecInteractionAction = reason == .notInterested ? .not_tonight : .show_me_another
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: specAction
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Track metrics
        MetricsService.shared.track(.rejectHard, properties: [
            "movie_id": gwMovie.id,
            "movie_title": gwMovie.title,
            "reason": reason.rawValue,
            "position": position + 1,
            "mode": "multi_pick",
            "replacement_number": totalReplacements + 1
        ])

        // Add to exclusions
        if let movieUUID = UUID(uuidString: gwMovie.id) {
            excludedMovieIds.insert(movieUUID)
        }

        // Collect ALL currently visible movie IDs BEFORE any replacement logic
        let visibleIds = Set(recommendedPicks.map { $0.id })

        #if DEBUG
        print("[CAROUSEL] Rejection: \(gwMovie.title) at position \(position)")
        print("[CAROUSEL] Visible IDs (\(visibleIds.count)): \(recommendedPicks.map { $0.title })")
        #endif

        // Build exclusion profile: rejected movie + ALL visible cards
        var updatedProfile = profile
        updatedProfile.notTonight.insert(gwMovie.id)
        for vid in visibleIds {
            updatedProfile.notTonight.insert(vid)
        }

        // After max replacements exhausted: remove card (no replacement search)
        // Interactions + tag learning still recorded above — only replacement is skipped
        if totalReplacements >= maxReplacements {
            withAnimation(.easeInOut(duration: 0.3)) {
                recommendedPicks.remove(at: position)
            }
            #if DEBUG
            print("[CAROUSEL] Max replacements (\(maxReplacements)) reached. Removing \(gwMovie.title). Count: \(recommendedPicks.count)")
            #endif
            return
        }

        // Pre-filter pool: remove ALL visible movies from the pool before engine sees it
        let filteredPool = validMoviePool.filter { !visibleIds.contains($0.id) }

        #if DEBUG
        print("[CAROUSEL] Pool size: \(validMoviePool.count) -> filtered: \(filteredPool.count) (excluded \(visibleIds.count) visible)")
        #endif

        // Find replacement with retry logic (up to 3 attempts)
        var replacement: GWMovie? = nil
        // Include ALL previously rejected movie IDs (not just currently visible ones)
        // to prevent a rejected-then-replaced movie from returning as a future replacement
        let rejectedIdStrings = Set(excludedMovieIds.map { $0.uuidString })
        var extraExclusions: Set<String> = visibleIds.union(rejectedIdStrings)

        for attempt in 1...3 {
            let candidate = engine.findReplacement(
                from: filteredPool,
                profile: updatedProfile,
                rejectedMovie: gwMovie,
                reason: reason,
                currentPicks: recommendedPicks,
                excluding: extraExclusions
            )

            if let candidate = candidate {
                // Triple-check: not a duplicate of any visible card or previous failed attempt
                if !visibleIds.contains(candidate.id) && !extraExclusions.contains(candidate.id) {
                    replacement = candidate
                    #if DEBUG
                    print("[CAROUSEL] Replacement found on attempt \(attempt): \(candidate.title)")
                    #endif
                    break
                } else {
                    // Duplicate returned despite pre-filtering -- add to exclusions and retry
                    extraExclusions.insert(candidate.id)
                    updatedProfile.notTonight.insert(candidate.id)
                    #if DEBUG
                    print("[CAROUSEL] BLOCKED DUPLICATE on attempt \(attempt): \(candidate.title), retrying")
                    #endif
                }
            } else {
                // No candidate at all -- pool exhausted
                #if DEBUG
                print("[CAROUSEL] No candidate on attempt \(attempt), pool exhausted")
                #endif
                break
            }
        }

        if let replacement = replacement {
            // HARD INVARIANT: final dedup check before insertion (belt-and-suspenders)
            if visibleIds.contains(replacement.id) {
                // Should never reach here after pre-filtering, but safety net
                #if DEBUG
                print("[CAROUSEL] FINAL CHECK BLOCKED DUPLICATE: \(replacement.title)")
                #endif
                totalReplacements += 1
                withAnimation(.easeInOut(duration: 0.3)) {
                    recommendedPicks.remove(at: position)
                }
                return
            }

            // Replace in-place at the same index (card count stays constant)
            // Incremental mutation: only the replaced card re-renders (identity by movie ID)
            replacedPositions.insert(position)
            totalReplacements += 1

            withAnimation(.easeInOut(duration: 0.3)) {
                recommendedPicks[position] = replacement
            }

            // Record replacement shown
            Task {
                if let movieUUID = UUID(uuidString: replacement.id) {
                    try? await InteractionService.shared.recordShown(
                        userId: userId,
                        movieId: movieUUID
                    )
                }
            }

            // Add replacement_shown interaction point
            GWInteractionPoints.shared.add(1)

            #if DEBUG
            print("[CAROUSEL] Replaced \(totalReplacements)/\(maxReplacements): \(gwMovie.title) -> \(replacement.title)")
            #endif
        } else {
            // Pool truly exhausted after retries -- remove card (4 cards is better than 5 with a duplicate)
            totalReplacements += 1

            withAnimation(.easeInOut(duration: 0.3)) {
                recommendedPicks.remove(at: position)
            }

            #if DEBUG
            print("[CAROUSEL] No unique replacement for \(gwMovie.title) after 3 retries. Card removed. Count: \(recommendedPicks.count)")
            #endif
        }
    }

    private func fetchNextAfterAlreadySeen(movieId: UUID) {
        isLoadingRecommendation = true
        recommendationError = nil
        excludedMovieIds.insert(movieId)

        Task {
            guard let userId = AuthGuard.shared.currentUserId,
                  let profile = UserService.shared.currentProfile else {
                fetchRecommendation()
                return
            }

            do {
                let nextMovie = try await MovieRecommendationService.shared.getSimilarButUnseen(
                    userId: userId,
                    profile: profile,
                    seenMovieId: movieId
                )

                await MainActor.run {
                    if let movie = nextMovie {
                        let gwMovie = GWMovie(from: movie)
                        self.assignCurrentMovie(movie, fallbackPool: [])
                        self.currentGoodScore = gwMovie.composite_score > 0 ? Int(round(gwMovie.composite_score)) : Int(round(gwMovie.goodscore * 10))
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false
                        self.recommendationShownTime = Date()  // Start decision timer

                        MetricsService.shared.track(.pickShown, properties: [
                            "movie_id": movie.id.uuidString,
                            "movie_title": movie.title,
                            "good_score": self.currentGoodScore,
                            "recommendation_number": self.sessionRecommendationCount,
                            "after_already_seen": true
                        ])

                        Task {
                            try? await InteractionService.shared.recordShown(
                                userId: userId,
                                movieId: movie.id
                            )
                        }
                    } else {
                        self.currentMovie = nil
                        self.isLoadingRecommendation = false
                        self.isLoadingNextMovie = false
                        self.showNoMoreMatches = true
                        self.recommendationError = "No more matches for your current preferences. Try changing your mood or platforms."
                    }
                }
            } catch {
                Crashlytics.crashlytics().record(error: error)
                await MainActor.run {
                    self.isLoadingRecommendation = false
                    self.isLoadingNextMovie = false
                    self.showNoMoreMatches = true
                    self.recommendationError = "Something went wrong. Please try again."
                }
            }
        }
    }

    // MARK: - Historical Exclusions

    /// Fetch movie IDs that were shown or rejected in last 30 days from Supabase
    /// Merged with session-local exclusions to prevent cross-session repeats
    private func fetchHistoricalExclusions(userId: UUID) async -> Set<UUID> {
        do {
            // getRecentlyRejectedMovieIds — fetches last 7 days of not_tonight + already_seen
            // getRecentlyShownMovieIds — fetches last 30 days of shown interactions
            async let rejected = InteractionService.shared.getRecentlyRejectedMovieIds(userId: userId)
            async let shown = InteractionService.shared.getRecentlyShownMovieIds(userId: userId)

            let rejectedIds = try await rejected
            let shownIds = try await shown

            #if DEBUG
            print("[INFO] Historical exclusions: \(rejectedIds.count) rejected + \(shownIds.count) shown = \(rejectedIds.union(shownIds).count) total")
            #endif

            return rejectedIds.union(shownIds)
        } catch {
            Crashlytics.crashlytics().record(error: error)
            #if DEBUG
            print("[WARN] Failed to fetch historical exclusions: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Helpers

    private func stopConditionMessage(_ condition: GWStopCondition) -> String {
        // GWStopCondition already has a user-friendly description
        condition.description
    }

    // MARK: - DEBUG Tools

    #if DEBUG

    /// Skip straight to recommendation with preset context (Feel-good + Netflix/Prime + English + Movie)
    /// Triggered by the bug icon on the landing screen
    private func debugSkipToRecommendation() {
        print("[DEV] DEBUG: Skipping to recommendation with preset context")

        userContext = UserContext(
            otts: [.netflix, .prime, .jioHotstar],
            mood: .feelGood,
            maxDuration: 180,
            minDuration: 60,
            languages: [.english, .hindi],
            intent: GWIntent(
                mood: "feel_good",
                energy: .calm,
                cognitive_load: .light,
                intent_tags: ["feel_good", "uplifting", "safe_bet", "light", "calm"]
            ),
            requiresSeries: false
        )

        navigateTo(.confidenceMoment)
        fetchRecommendation()
    }

    /// Debug info about the current recommendation — used by MainScreenView overlay
    var debugOverlayInfo: DebugRecommendationInfo? {
        guard let movie = currentMovie else { return nil }
        let gwMovie = GWMovie(from: movie)
        let profile = GWUserProfileComplete.from(
            context: userContext,
            userId: AuthGuard.shared.currentUserId?.uuidString ?? "anon",
            excludedIds: excludedMovieIds.map { $0.uuidString }
        )
        let matchScore = engine.computeScore(movie: gwMovie, profile: profile)
        return DebugRecommendationInfo(
            contentType: movie.content_type ?? "nil",
            tags: gwMovie.tags,
            intentTags: profile.intentTags,
            matchScore: matchScore,
            compositeScore: gwMovie.composite_score,
            goodscore: gwMovie.goodscore,
            displayedScore: currentGoodScore,
            candidateCount: sessionRecommendationCount,
            mood: userContext.mood.rawValue,
            platforms: userContext.otts.map { $0.displayName },
            runtime: movie.runtimeMinutes,
            providerCount: movie.supportedProviders.count,
            allProviderNames: movie.ott_providers?.map { $0.name } ?? []
        )
    }

    #endif
}

/// Debug info struct for the recommendation overlay (DEBUG only)
#if DEBUG
struct DebugRecommendationInfo {
    let contentType: String
    let tags: [String]
    let intentTags: [String]
    let matchScore: Double
    let compositeScore: Double
    let goodscore: Double
    let displayedScore: Int
    let candidateCount: Int
    let mood: String
    let platforms: [String]
    let runtime: Int
    let providerCount: Int
    let allProviderNames: [String]
}
#endif
