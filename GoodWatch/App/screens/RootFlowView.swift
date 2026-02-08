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

    // Rejection sheet
    @State private var showRejectionSheet: Bool = false

    // Session tracking
    @State private var sessionRecommendationCount: Int = 0

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
        }
    }

    // MARK: - Screen Router

    @ViewBuilder
    private var screenView: some View {
        switch currentScreen {
        case .landing:
            LandingView(onContinue: {
                navigateTo(.auth)
            })

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
                }
            )

        case .confidenceMoment:
            ConfidenceMomentView(onComplete: {
                navigateTo(.mainScreen)
            })

        case .mainScreen:
            mainScreenContent

        case .enjoyScreen:
            enjoyScreenContent
        }
    }

    // MARK: - Main Screen Content

    @ViewBuilder
    private var mainScreenContent: some View {
        if let movie = currentMovie {
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
                }
            )
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

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "popcorn.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient.goldGradient)

                Text("Enjoy!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(LinearGradient.goldGradient)

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

        // Only resume if user is authenticated and has a saved step
        guard savedStep > 0, UserService.shared.currentUser != nil else {
            return
        }

        #if DEBUG
        print("Resuming from saved onboarding step: \(savedStep)")
        #endif

        // Map saved step to screen
        // Steps saved by screens:
        //   MoodSelector saves step 2
        //   PlatformSelector saves step 3
        //   DurationSelector saves step 4
        //   EmotionalHook saves step 5
        //   Completion saves step 6+
        switch savedStep {
        case 2:
            currentScreen = .platformSelector
        case 3:
            currentScreen = .durationSelector
        case 4:
            currentScreen = .emotionalHook
        case 5...:
            // User completed onboarding before - go to emotional hook
            // so they can get a fresh recommendation
            currentScreen = .emotionalHook
        default:
            currentScreen = .landing
        }
    }

    // MARK: - Recommendation Flow

    private func fetchRecommendation() {
        isLoadingRecommendation = true
        recommendationError = nil

        Task {
            // Ensure user exists
            let userId = await AuthGuard.shared.ensureUserExistsBeforeOnboarding()

            // Set metrics user context
            MetricsService.shared.setUser(
                id: userId.uuidString,
                authType: UserService.shared.currentUser?.auth_provider ?? "anonymous"
            )

            // Build profile from context
            let profile = GWUserProfileComplete.from(
                context: userContext,
                userId: userId.uuidString,
                excludedIds: excludedMovieIds.map { $0.uuidString }
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

                // Use canonical engine
                let output = engine.recommend(
                    fromRawMovies: movies,
                    profile: profile,
                    contentFilter: contentFilter
                )

                await MainActor.run {
                    if let gwMovie = output.movie,
                       let movie = movies.first(where: { $0.id.uuidString == gwMovie.id }) {
                        self.currentMovie = movie
                        self.currentGoodScore = Int(engine.computeScore(movie: gwMovie, profile: profile) * 100)
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false

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
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRecommendation = false
                    self.recommendationError = "Something went wrong. Please check your connection and try again."

                    #if DEBUG
                    print("Recommendation fetch error: \(error)")
                    #endif
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

            guard let profile = UserService.shared.currentProfile else {
                // Fall back to context-based recommendation
                fetchRecommendation()
                return
            }

            do {
                let nextMovie = try await MovieRecommendationService.shared.getNextAfterRejection(
                    userId: userId,
                    profile: profile,
                    rejectedMovieId: rejectedMovieId,
                    rejectionReason: reason
                )

                await MainActor.run {
                    if let movie = nextMovie {
                        let gwMovie = GWMovie(from: movie)
                        let canonicalProfile = GWUserProfileComplete.from(
                            context: userContext,
                            userId: userId.uuidString,
                            excludedIds: excludedMovieIds.map { $0.uuidString }
                        )
                        self.currentMovie = movie
                        self.currentGoodScore = Int(engine.computeScore(movie: gwMovie, profile: canonicalProfile) * 100)
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false

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
        guard let userId = AuthGuard.shared.currentUserId else { return }

        let rejectedId = movie.id

        // Track metrics
        MetricsService.shared.track(.rejectHard, properties: [
            "movie_id": movie.id.uuidString,
            "movie_title": movie.title,
            "reason": "already_seen",
            "recommendation_number": sessionRecommendationCount
        ])

        // Record interaction
        Task {
            try? await InteractionService.shared.recordAlreadySeen(
                userId: userId,
                movieId: movie.id
            )
        }

        // Fetch next similar movie
        fetchNextAfterAlreadySeen(movieId: rejectedId)
    }

    private func handleRejectionWithReason(_ reason: RejectionSheetView.RejectionReason) {
        guard let movie = currentMovie else { return }
        guard let userId = AuthGuard.shared.currentUserId else { return }

        let rejectedId = movie.id

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
        Task {
            try? await InteractionService.shared.recordRejectionWithLearning(
                userId: userId,
                movieId: movie.id,
                rejectionReason: reason.rawValue,
                platforms: userContext.otts.map { $0.rawValue }
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
                        let canonicalProfile = GWUserProfileComplete.from(
                            context: userContext,
                            userId: userId.uuidString,
                            excludedIds: excludedMovieIds.map { $0.uuidString }
                        )
                        self.currentMovie = movie
                        self.currentGoodScore = Int(engine.computeScore(movie: gwMovie, profile: canonicalProfile) * 100)
                        self.sessionRecommendationCount += 1
                        self.isLoadingRecommendation = false

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

    // MARK: - Helpers

    private func stopConditionMessage(_ condition: GWStopCondition) -> String {
        // GWStopCondition already has a user-friendly description
        condition.description
    }
}
