import SwiftUI

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
//   -> DurationSelector -> EmotionalHook -> ConfidenceMoment
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
        case durationSelector = 4
        case emotionalHook = 5
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
    @State private var excludedMovieIds: Set<UUID> = []
    @State private var recommendationReady: Bool = false
    @State private var confidenceMinTimeElapsed: Bool = false

    // Rejection sheet
    @State private var showRejectionSheet: Bool = false

    // Session tracking
    @State private var sessionRecommendationCount: Int = 0

    // Decision timing: tracks when current recommendation was shown
    // Used to measure how long user deliberates before accept/reject
    @State private var recommendationShownTime: Date? = nil

    // Feedback state
    @State private var pendingFeedback: FeedbackPromptData? = nil

    // Transition animation
    @State private var screenTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    // Services
    private let engine = GWRecommendationEngine.shared

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
        }
        .onAppear {
            resumeFromSavedState()
            checkForPendingFeedback()
        }
    }

    // MARK: - Screen Router

    @ViewBuilder
    private var screenView: some View {
        switch currentScreen {
        case .landing:
            LandingView(
                onContinue: {
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
                    navigateTo(.platformSelector)
                },
                onBack: {
                    navigateBack(to: .auth)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .platformSelector:
            PlatformSelectorView(
                ctx: $userContext,
                onNext: {
                    navigateTo(.durationSelector)
                },
                onBack: {
                    navigateBack(to: .moodSelector)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .durationSelector:
            DurationSelectorView(
                ctx: $userContext,
                onNext: {
                    navigateTo(.emotionalHook)
                },
                onBack: {
                    navigateBack(to: .platformSelector)
                },
                onHome: {
                    returnToLanding()
                }
            )

        case .emotionalHook:
            EmotionalHookView(
                userContext: userContext,
                onShowMe: {
                    navigateTo(.confidenceMoment)
                    fetchRecommendation()
                },
                onBack: {
                    navigateBack(to: .durationSelector)
                },
                onChangePlatforms: {
                    navigateBack(to: .platformSelector)
                },
                onChangeRuntime: {
                    navigateBack(to: .durationSelector)
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
        if let movie = currentMovie {
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
                    returnToLanding()
                },
                onExplore: {
                    navigateTo(.explore)
                },
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
                    returnToLanding()
                },
                onExplore: {
                    navigateTo(.explore)
                }
            )
            #endif
        } else if let error = recommendationError {
            noRecommendationView(message: error)
        } else {
            // Still loading - show confidence moment style loading
            ConfidenceMomentView(onComplete: {})
        }
    }

    // MARK: - Enjoy Screen Content

    @ViewBuilder
    private var enjoyScreenContent: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            // Blurred movie backdrop behind content
            if let url = currentMovie?.posterURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: 12)
                            .brightness(-0.5)
                            .scaleEffect(1.1)
                            .clipped()
                            .ignoresSafeArea()
                    }
                }

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
            }

            VStack(spacing: 24) {
                Spacer()

                // Movie poster thumbnail
                if let url = currentMovie?.posterURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 200)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
                        default:
                            EmptyView()
                        }
                    }
                }

                Text("Enjoy!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(LinearGradient.goldGradient)

                if let title = currentMovie?.title {
                    Text(title)
                        .font(GWTypography.body(weight: .semibold))
                        .foregroundColor(GWColors.white)
                }

                Text("We hope you love it.")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.lightGray)

                Spacer()

                Button {
                    returnToLanding()
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
                    returnToLanding()
                } label: {
                    Text("Done for tonight")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            // Auto-return to landing after 5 seconds if user doesn't tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if currentScreen == .enjoyScreen {
                    returnToLanding()
                }
            }
        }
    }

    // MARK: - Feedback Screen Content

    @ViewBuilder
    private var feedbackScreenContent: some View {
        if let feedback = pendingFeedback {
            PostWatchFeedbackView(
                feedbackData: feedback,
                onCompleted: {
                    handleFeedbackSubmission(movieId: feedback.movieId, status: .completed)
                },
                onAbandoned: {
                    handleFeedbackSubmission(movieId: feedback.movieId, status: .abandoned)
                },
                onSkipped: {
                    handleFeedbackSubmission(movieId: feedback.movieId, status: .skipped)
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
            print("📋 Showing overdue feedback for: \(feedback.movieTitle)")
            #endif
        }
    }

    private func handleFeedbackSubmission(movieId: String, status: GWFeedbackStatus) {
        guard let userId = AuthGuard.shared.currentUserId else {
            navigateTo(.landing)
            return
        }

        // Submit feedback via enforcer (handles Supabase logging + tag weight update)
        switch status {
        case .completed:
            GWFeedbackEnforcer.shared.markCompleted(movieId: movieId, userId: userId.uuidString)

            // Update tag weights with completed signal
            // We need the movie's tags — look up from pending feedback list
            MetricsService.shared.track(.feedbackGiven, properties: [
                "movie_id": movieId,
                "sentiment": "completed"
            ])

        case .abandoned:
            GWFeedbackEnforcer.shared.markAbandoned(movieId: movieId, userId: userId.uuidString)

            MetricsService.shared.track(.feedbackGiven, properties: [
                "movie_id": movieId,
                "sentiment": "abandoned"
            ])

        case .skipped:
            GWFeedbackEnforcer.shared.skipFeedback(movieId: movieId, userId: userId.uuidString)

            MetricsService.shared.track(.feedbackGiven, properties: [
                "movie_id": movieId,
                "sentiment": "skipped"
            ])

        case .pending:
            break
        }

        // Clear feedback state and go to landing
        pendingFeedback = nil
        navigateTo(.landing)
    }

    /// Return to landing, resetting session state
    private func returnToLanding() {
        // Reset recommendation state for fresh session
        currentMovie = nil
        currentGoodScore = 0
        recommendationError = nil
        excludedMovieIds = []
        sessionRecommendationCount = 0
        showRejectionSheet = false
        userContext = .default

        navigateBack(to: .landing)
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
                navigateBack(to: .platformSelector)
            } label: {
                Text("Adjust preferences")
                    .font(GWTypography.button())
                    .foregroundColor(GWColors.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.goldGradient)
                    .cornerRadius(GWRadius.lg)
            }
            .padding(.horizontal, GWSpacing.screenPadding)

            Button {
                navigateBack(to: .landing)
            } label: {
                Text("Start over")
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
    }

    // MARK: - Navigation

    private func navigateTo(_ screen: Screen) {
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

        // Map saved step to screen (only for incomplete onboarding)
        // Steps saved by screens:
        //   MoodSelector saves step 2
        //   PlatformSelector saves step 3
        //   DurationSelector saves step 4
        //   EmotionalHook saves step 5
        switch savedStep {
        case 2:
            currentScreen = .platformSelector
        case 3:
            currentScreen = .durationSelector
        case 4, 5:
            currentScreen = .emotionalHook
        default:
            currentScreen = .landing
        }
    }

    // MARK: - Recommendation Flow

    private func fetchRecommendation() {
        isLoadingRecommendation = true
        recommendationError = nil
        recommendationReady = false
        confidenceMinTimeElapsed = false

        Task {
            // Ensure user exists
            let userId = await AuthGuard.shared.ensureUserExistsBeforeOnboarding()

            // Set metrics user context
            MetricsService.shared.setUser(
                id: userId.uuidString,
                authType: UserService.shared.currentUser?.auth_provider ?? "anonymous"
            )

            // Set user for per-user tag weights
            TagWeightStore.shared.setUser(userId.uuidString)

            // Fetch shown/rejected history from Supabase to avoid cross-session repeats
            let historicalExclusions = await fetchHistoricalExclusions(userId: userId)
            let allExcludedIds = excludedMovieIds.union(historicalExclusions)

            // Build profile from context — uses combined session + historical exclusions
            let profile = GWUserProfileComplete.from(
                context: userContext,
                userId: userId.uuidString,
                excludedIds: allExcludedIds.map { $0.uuidString }
            )

            // Get user maturity info for content filtering
            let maturityInfo = await InteractionService.shared.getUserMaturityInfo(userId: userId)
            let contentFilter = GWNewUserContentFilter(maturityInfo: maturityInfo)

            // Fetch movies from Supabase
            do {
                let contentTypeFilter: String? = userContext.requiresSeries ? "tv" : "movie"
                let userLanguages = userContext.languages.map { $0.rawValue }

                let movies = try await SupabaseService.shared.fetchMoviesForAvailabilityCheck(
                    languages: userLanguages,
                    contentType: contentTypeFilter,
                    acceptCount: 0,
                    limit: 1000
                )

                #if DEBUG
                print("🎬 RECOMMENDATION DEBUG:")
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
                print("🔍 DIAGNOSTIC: \(movies.count) movies fetched, \(validCount) valid")
                print("🔍 Failure breakdown: \(allFailureCounts)")
                print("🔍 Profile: platforms=\(profile.platforms), langs=\(profile.preferredLanguages), runtime=\(profile.runtimeWindow.min)-\(profile.runtimeWindow.max), intentTags=\(profile.intentTags)")

                // Use canonical engine with production fallback
                let (output, fallbackLevel, _) = engine.recommendWithFallback(
                    fromRawMovies: movies,
                    profile: profile,
                    contentFilter: contentFilter
                )

                if fallbackLevel != .none {
                    print("⚠️ Used fallback level \(fallbackLevel.rawValue) to find recommendation")
                }

                #if DEBUG
                if let gwMovie = output.movie {
                    let rawMovie = movies.first(where: { $0.id.uuidString == gwMovie.id })
                    print("   ✅ RECOMMENDED: \(gwMovie.title)")
                    print("      content_type: \(rawMovie?.content_type ?? "nil")")
                    print("      tags: \(gwMovie.tags)")
                    print("      goodscore: \(gwMovie.goodscore), composite: \(gwMovie.composite_score)")
                    print("      score: \(engine.computeScore(movie: gwMovie, profile: profile))")
                    let intentTags = Set(profile.intentTags)
                    let movieTags = Set(gwMovie.tags)
                    print("      tag intersection: \(movieTags.intersection(intentTags))")
                } else {
                    print("   ❌ NO RECOMMENDATION: \(output.stopCondition?.description ?? "unknown")")
                }
                #endif

                await MainActor.run {
                    if let gwMovie = output.movie,
                       let movie = movies.first(where: { $0.id.uuidString == gwMovie.id }) {
                        self.currentMovie = movie
                        self.currentGoodScore = gwMovie.composite_score > 0 ? Int(round(gwMovie.composite_score)) : Int(round(gwMovie.goodscore * 10))
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false
                        self.recommendationShownTime = Date()  // Start decision timer

                        // Track metrics
                        MetricsService.shared.track(.pickShown, properties: [
                            "movie_id": movie.id.uuidString,
                            "movie_title": movie.title,
                            "good_score": self.currentGoodScore,
                            "recommendation_number": self.sessionRecommendationCount
                        ])

                        // Record shown interaction
                        Task {
                            try? await InteractionService.shared.recordShown(
                                userId: userId,
                                movieId: movie.id
                            )
                        }

                        // Mark onboarding as complete
                        GWKeychainManager.shared.storeOnboardingStep(6)

                        if self.sessionRecommendationCount == 1 {
                            MetricsService.shared.track(.onboardingComplete)
                            MetricsService.shared.track(.firstRecommendation, properties: [
                                "movie_title": movie.title
                            ])
                        }

                        // Signal recommendation ready for ConfidenceMoment transition
                        self.recommendationReady = true
                        self.tryTransitionToMainScreen()
                    } else {
                        self.currentMovie = nil
                        self.isLoadingRecommendation = false

                        if let stopCondition = output.stopCondition {
                            self.recommendationError = stopConditionMessage(stopCondition)
                        } else {
                            self.recommendationError = "We couldn't find a match for your preferences. Try adjusting your platforms or language."
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
                    print("🎬 RETRY RECOMMENDATION: \(gwMovie.title)")
                    print("   tags: \(gwMovie.tags), intent: \(profile.intentTags)")
                    print("   score: \(engine.computeScore(movie: gwMovie, profile: profile))")
                } else {
                    print("🎬 RETRY: No recommendation — \(output.stopCondition?.description ?? "unknown")")
                }
                #endif

                await MainActor.run {
                    if let gwMovie = output.movie,
                       let movie = movies.first(where: { $0.id.uuidString == gwMovie.id }) {
                        self.currentMovie = movie
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
                        self.recommendationError = "We've shown you all our best picks for tonight. Try adjusting your mood or platforms."
                    }
                }
            } catch {
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

        // Record interaction
        Task {
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
        let rejectedId = movie.id

        // Track metrics
        MetricsService.shared.track(.rejectHard, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "reason": "already_seen",
            "recommendation_number": sessionRecommendationCount
        ])

        // Record interaction (if authenticated)
        if let userId = AuthGuard.shared.currentUserId {
            Task {
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

        let rejectedId = movie.id

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

        // Record interaction with learning signal
        // BUG FIX: Pass the MOVIE's platforms, not all user platforms
        // Previously this corrupted platform bias by penalizing unrelated platforms
        Task {
            try? await InteractionService.shared.recordRejectionWithLearning(
                userId: userId,
                movieId: movie.id,
                rejectionReason: reason.rawValue,
                platforms: movie.platformNames
            )

            // Update tag weights (negative signal)
            let gwMovie = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: .not_tonight
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Fetch next recommendation
        fetchNextRecommendation(afterRejection: rejectedId, reason: reason.rawValue)
    }

    private func handleShowAnother() {
        guard let movie = currentMovie else { return }
        guard let userId = AuthGuard.shared.currentUserId else { return }

        let rejectedId = movie.id

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
            try? await InteractionService.shared.recordNotTonight(
                userId: userId,
                movieId: movie.id,
                reason: "show_another"
            )

            // Weak tag weight signal: "show me another" = very mild negative
            // User didn't actively reject, but wasn't excited enough to watch
            // Threshold-gated: always collected, but delta is tiny (-0.02) so it only
            // matters after many interactions accumulate
            let gwMovie = GWMovie(from: movie)
            let updatedWeights = updateTagWeights(
                tagWeights: TagWeightStore.shared.getWeights(),
                movie: gwMovie,
                action: .show_me_another
            )
            TagWeightStore.shared.saveWeights(updatedWeights)
        }

        // Fetch next recommendation
        fetchNextRecommendation(afterRejection: rejectedId, reason: nil)
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
                        self.currentMovie = movie
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
                        self.recommendationError = "No more matches for your current preferences. Try changing your mood or platforms."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRecommendation = false
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
            print("📋 Historical exclusions: \(rejectedIds.count) rejected + \(shownIds.count) shown = \(rejectedIds.union(shownIds).count) total")
            #endif

            return rejectedIds.union(shownIds)
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch historical exclusions: \(error)")
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
        print("🐛 DEBUG: Skipping to recommendation with preset context")

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
