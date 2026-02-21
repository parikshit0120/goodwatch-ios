import SwiftUI

// ============================================
// WATCH FEEDBACK VIEW — 2-Stage Post-Watch Feedback
// ============================================
//
// NEW file — does NOT replace PostWatchFeedbackView.swift or GWReviewPromptView.swift.
// Those are kept intact for rollback safety.
//
// Stage 1: Quick Check-in (5 seconds max)
//   - Did you finish it? (Yes / No / Started but stopped)
//   - How do you feel now? (Better / Same / Worse)
//   - Would you pick this again? (Thumbs up / down)
//   - Auto-dismiss after 30 seconds of no interaction
//
// Stage 2: Deeper Feedback (OPTIONAL, only if Stage 1 completed)
//   - 3 emotional sliders (Cozy-Intense, Chill-Energizing, Serious-Funny)
//   - Star rating (1-5)
//   - Optional text review (280 chars)
//
// Data writes:
//   Stage 1 → watch_feedback (finished, mood_after, would_pick_again)
//   Stage 2 → watch_feedback (felt_comfort, felt_intensity, felt_energy, felt_humour, satisfaction)
//           → user_reviews (rating, review_text) via GWReviewService
//
// Trigger: One-line swap in RootFlowView.swift (use unlock.sh)
// ============================================

// MARK: - Feedback Stage

private enum FeedbackStage {
    case stage1
    case stage2
    case thankYou
}

// MARK: - Stage 1 Models

private enum FinishStatus: String {
    case yes = "yes"
    case no = "no"
    case partial = "partial"

    var boolValue: Bool? {
        switch self {
        case .yes: return true
        case .no: return false
        case .partial: return false
        }
    }
}

private enum MoodAfter: String {
    case better = "better"
    case same = "same"
    case worse = "worse"
}

// MARK: - Main View

struct GWWatchFeedbackView: View {
    let movieTitle: String
    let movieId: String
    let posterURL: String?

    // Callbacks
    let onComplete: () -> Void

    // Stage tracking
    @State private var stage: FeedbackStage = .stage1
    @State private var appearOpacity: Double = 0

    // Stage 1 state
    @State private var finishStatus: FinishStatus? = nil
    @State private var moodAfter: MoodAfter? = nil
    @State private var wouldPickAgain: Bool? = nil
    @State private var isSubmittingStage1 = false

    // Stage 2 state
    @State private var sliderCozyIntense: Int = 3     // 1=Cozy, 5=Intense
    @State private var sliderChillEnergizing: Int = 3  // 1=Chill, 5=Energizing
    @State private var sliderSeriousFunny: Int = 3     // 1=Serious, 5=Funny
    @State private var starRating: Int = 0
    @State private var reviewText: String = ""
    @State private var isSubmittingStage2 = false

    // Auto-dismiss timer
    @State private var autoDismissTask: DispatchWorkItem? = nil

    var body: some View {
        ZStack {
            GWColors.black.ignoresSafeArea()

            switch stage {
            case .stage1:
                stage1Content
                    .transition(.opacity)
            case .stage2:
                stage2Content
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            case .thankYou:
                thankYouContent
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(appearOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appearOpacity = 1
            }
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    // MARK: - Auto-Dismiss Timer (30 seconds)

    private func startAutoDismissTimer() {
        autoDismissTask?.cancel()
        let task = DispatchWorkItem {
            if stage == .stage1 && finishStatus == nil {
                // No interaction at all — track timeout and dismiss
                MetricsService.shared.track(.feedbackTimeout, properties: ["movie_id": movieId])
                onComplete()
            }
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: task)
    }

    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
    }

    // MARK: - Stage 1: Quick Check-in

    private var stage1Content: some View {
        VStack(spacing: 0) {
            Spacer()

            // Movie poster + title
            movieHeader
                .padding(.bottom, 24)

            // Question 1: Did you finish it?
            VStack(spacing: 8) {
                Text("Did you finish it?")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.white)

                HStack(spacing: 12) {
                    finishButton("Yes", status: .yes)
                    finishButton("No", status: .no)
                    finishButton("Partially", status: .partial)
                }
            }
            .padding(.bottom, 20)

            // Question 2: How do you feel now?
            VStack(spacing: 8) {
                Text("How do you feel now?")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.white)

                HStack(spacing: 16) {
                    moodButton("Better", emoji: "B", mood: .better)
                    moodButton("Same", emoji: "S", mood: .same)
                    moodButton("Worse", emoji: "W", mood: .worse)
                }
            }
            .padding(.bottom, 20)

            // Question 3: Would you pick this again?
            VStack(spacing: 8) {
                Text("Would you pick this again?")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.white)

                HStack(spacing: 20) {
                    pickAgainButton(true)
                    pickAgainButton(false)
                }
            }
            .padding(.bottom, 32)

            // Submit button
            Button {
                submitStage1()
            } label: {
                Text(isSubmittingStage1 ? "Saving..." : "Submit")
                    .font(GWTypography.button())
                    .foregroundColor(GWColors.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(stage1IsValid ? LinearGradient.goldGradient : LinearGradient(colors: [GWColors.lightGray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(GWRadius.lg)
            }
            .disabled(!stage1IsValid || isSubmittingStage1)
            .padding(.horizontal, GWSpacing.screenPadding)

            Spacer()
        }
        .padding(.horizontal, GWSpacing.screenPadding)
    }

    private var stage1IsValid: Bool {
        finishStatus != nil && moodAfter != nil && wouldPickAgain != nil
    }

    // MARK: - Stage 2: Deeper Feedback

    private var stage2Content: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text("Quick -- how did it feel?")
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)
                    .padding(.bottom, 24)

                // Slider 1: Cozy <-> Intense
                emotionalSlider(
                    leftLabel: "Cozy",
                    rightLabel: "Intense",
                    value: $sliderCozyIntense
                )
                .padding(.bottom, 20)

                // Slider 2: Chill <-> Energizing
                emotionalSlider(
                    leftLabel: "Chill",
                    rightLabel: "Energizing",
                    value: $sliderChillEnergizing
                )
                .padding(.bottom, 20)

                // Slider 3: Serious <-> Funny
                emotionalSlider(
                    leftLabel: "Serious",
                    rightLabel: "Funny",
                    value: $sliderSeriousFunny
                )
                .padding(.bottom, 28)

                // Star Rating
                VStack(spacing: 8) {
                    Text("Rating")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.white)

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= starRating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    star <= starRating
                                    ? LinearGradient.goldGradient
                                    : LinearGradient(colors: [GWColors.lightGray], startPoint: .top, endPoint: .bottom)
                                )
                                .scaleEffect(star <= starRating ? 1.1 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: starRating)
                                .onTapGesture { starRating = star }
                        }
                    }

                    if starRating > 0 {
                        Text(ratingLabel(starRating))
                            .font(GWTypography.small(weight: .medium))
                            .foregroundColor(GWColors.gold)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 20)

                // Optional text review
                if starRating > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("Quick thought (optional)", text: $reviewText, axis: .vertical)
                            .font(GWTypography.body())
                            .foregroundColor(GWColors.white)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(GWColors.black.opacity(0.5))
                            .cornerRadius(GWRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: GWRadius.md)
                                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
                            )

                        Text("\(reviewText.count)/280")
                            .font(GWTypography.tiny())
                            .foregroundColor(reviewText.count > 280 ? .red : GWColors.lightGray)
                    }
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Submit / Skip buttons
                VStack(spacing: 12) {
                    Button {
                        submitStage2()
                    } label: {
                        Text(isSubmittingStage2 ? "Saving..." : "Submit")
                            .font(GWTypography.button())
                            .foregroundColor(GWColors.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(LinearGradient.goldGradient)
                            .cornerRadius(GWRadius.lg)
                    }
                    .disabled(isSubmittingStage2 || reviewText.count > 280)

                    Button {
                        MetricsService.shared.track(.feedbackStage2Skipped, properties: ["movie_id": movieId])
                        showThankYou()
                    } label: {
                        Text("Skip")
                            .font(GWTypography.body(weight: .medium))
                            .foregroundColor(GWColors.lightGray)
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, GWSpacing.screenPadding)
        }
    }

    // MARK: - Thank You

    private var thankYouContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.goldGradient)

            Text("Thanks!")
                .font(GWTypography.headline())
                .foregroundColor(GWColors.white)

            Text("Your feedback helps us pick better for you.")
                .font(GWTypography.body())
                .foregroundColor(GWColors.lightGray)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, GWSpacing.screenPadding)
    }

    // MARK: - Movie Header

    private var movieHeader: some View {
        HStack(spacing: 12) {
            if let url = posterURL {
                GWCachedImage(url: url) {
                    RoundedRectangle(cornerRadius: GWRadius.sm)
                        .fill(GWColors.darkGray)
                        .frame(width: 50, height: 75)
                }
                .frame(width: 50, height: 75)
                .cornerRadius(GWRadius.sm)
            }

            Text(movieTitle)
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.white)
                .lineLimit(2)
        }
    }

    // MARK: - Reusable Buttons

    private func finishButton(_ label: String, status: FinishStatus) -> some View {
        Button {
            cancelAutoDismiss()
            withAnimation(.easeOut(duration: 0.15)) { finishStatus = status }
        } label: {
            Text(label)
                .font(GWTypography.small(weight: .medium))
                .foregroundColor(finishStatus == status ? GWColors.black : GWColors.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    finishStatus == status
                    ? AnyShapeStyle(LinearGradient.goldGradient)
                    : AnyShapeStyle(Color.white.opacity(0.08))
                )
                .cornerRadius(GWRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.md)
                        .stroke(finishStatus == status ? Color.clear : GWColors.surfaceBorder, lineWidth: 1)
                )
        }
    }

    private func moodButton(_ label: String, emoji: String, mood: MoodAfter) -> some View {
        Button {
            cancelAutoDismiss()
            withAnimation(.easeOut(duration: 0.15)) { moodAfter = mood }
        } label: {
            VStack(spacing: 4) {
                Text(moodEmoji(mood))
                    .font(.system(size: 28))
                Text(label)
                    .font(GWTypography.small(weight: .medium))
                    .foregroundColor(moodAfter == mood ? GWColors.gold : GWColors.lightGray)
            }
            .frame(width: 72, height: 64)
            .background(moodAfter == mood ? GWColors.gold.opacity(0.15) : Color.white.opacity(0.05))
            .cornerRadius(GWRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: GWRadius.md)
                    .stroke(moodAfter == mood ? GWColors.gold.opacity(0.5) : GWColors.surfaceBorder, lineWidth: 1)
            )
        }
    }

    private func moodEmoji(_ mood: MoodAfter) -> String {
        switch mood {
        case .better: return ":)"
        case .same: return ":|"
        case .worse: return ":("
        }
    }

    private func pickAgainButton(_ pick: Bool) -> some View {
        Button {
            cancelAutoDismiss()
            withAnimation(.easeOut(duration: 0.15)) { wouldPickAgain = pick }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: pick ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .font(.system(size: 20))
                Text(pick ? "Yes" : "No")
                    .font(GWTypography.body(weight: .medium))
            }
            .foregroundColor(wouldPickAgain == pick ? (pick ? GWColors.gold : GWColors.white) : GWColors.lightGray)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                wouldPickAgain == pick
                ? (pick ? GWColors.gold.opacity(0.15) : Color.white.opacity(0.1))
                : Color.white.opacity(0.05)
            )
            .cornerRadius(GWRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: GWRadius.md)
                    .stroke(
                        wouldPickAgain == pick
                        ? (pick ? GWColors.gold.opacity(0.5) : GWColors.surfaceBorder)
                        : GWColors.surfaceBorder,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Emotional Slider

    private func emotionalSlider(leftLabel: String, rightLabel: String, value: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(leftLabel)
                    .font(GWTypography.small())
                    .foregroundColor(GWColors.lightGray)
                Spacer()
                Text(rightLabel)
                    .font(GWTypography.small())
                    .foregroundColor(GWColors.lightGray)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { position in
                    Button {
                        value.wrappedValue = position
                    } label: {
                        Circle()
                            .fill(position <= value.wrappedValue ? GWColors.gold : Color.white.opacity(0.15))
                            .frame(width: position == value.wrappedValue ? 28 : 20,
                                   height: position == value.wrappedValue ? 28 : 20)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: value.wrappedValue)
                    }
                    if position < 5 {
                        Rectangle()
                            .fill(position < value.wrappedValue ? GWColors.gold.opacity(0.5) : Color.white.opacity(0.1))
                            .frame(height: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "Not for me"
        case 2: return "It was okay"
        case 3: return "Decent watch"
        case 4: return "Really enjoyed it"
        case 5: return "Loved it"
        default: return ""
        }
    }

    private func currentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        case 21..<24: return "night"
        default: return "late_night" // 0-4
        }
    }

    private func currentDayOfWeek() -> Int {
        // 0=Sunday, 1=Monday, ... 6=Saturday
        return Calendar.current.component(.weekday, from: Date()) - 1
    }

    // MARK: - Submit Stage 1

    private func submitStage1() {
        guard stage1IsValid, let finish = finishStatus, let mood = moodAfter, let pick = wouldPickAgain else { return }
        isSubmittingStage1 = true
        cancelAutoDismiss()

        // Track event
        MetricsService.shared.track(.feedbackStage1Completed, properties: [
            "movie_id": movieId,
            "finished": finish.rawValue,
            "mood_after": mood.rawValue,
            "would_pick_again": pick
        ])

        // Fire-and-forget Supabase write
        Task {
            await GWWatchFeedbackService.upsertStage1(
                movieId: movieId,
                finished: finish.boolValue,
                moodAfter: mood.rawValue,
                wouldPickAgain: pick,
                timeOfDay: currentTimeOfDay(),
                dayOfWeek: currentDayOfWeek()
            )

            // Also update tag weights via existing feedback enforcer
            let feedbackStatus: GWFeedbackStatus = finish == .yes ? .completed : .abandoned
            if let userId = AuthGuard.shared.currentUserId {
                GWFeedbackEnforcer.shared.submitFeedback(
                    movieId: movieId,
                    userId: userId.uuidString,
                    status: feedbackStatus
                )
            }
        }

        // Transition to stage 2
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSubmittingStage1 = false
            stage = .stage2
        }
    }

    // MARK: - Submit Stage 2

    private func submitStage2() {
        isSubmittingStage2 = true

        // Map sliders to felt_ dimensions
        let feltComfort = 6 - sliderCozyIntense       // Inverted: 1=cozy(5) to 5=intense(1)
        let feltIntensity = sliderCozyIntense          // Direct: 1=low to 5=high
        let feltEnergy = sliderChillEnergizing         // Direct: 1=low to 5=high
        let feltHumour = sliderSeriousFunny            // Direct: 1=serious(low) to 5=funny(high)

        // Track event
        MetricsService.shared.track(.feedbackStage2Completed, properties: [
            "movie_id": movieId,
            "felt_comfort": feltComfort,
            "felt_intensity": feltIntensity,
            "felt_energy": feltEnergy,
            "felt_humour": feltHumour,
            "star_rating": starRating,
            "has_text": !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ])

        // Fire-and-forget Supabase writes
        Task {
            // Update watch_feedback with Stage 2 data
            await GWWatchFeedbackService.upsertStage2(
                movieId: movieId,
                feltComfort: feltComfort,
                feltIntensity: feltIntensity,
                feltEnergy: feltEnergy,
                feltHumour: feltHumour,
                satisfaction: starRating > 0 ? starRating : nil
            )

            // Also write to user_reviews for backward compat (existing UGC table)
            if starRating > 0 {
                let trimmedText = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalText: String? = trimmedText.isEmpty ? nil : String(trimmedText.prefix(280))

                if let userId = AuthGuard.shared.currentUserId {
                    await GWReviewService.submitReview(
                        userId: userId.uuidString,
                        movieId: movieId,
                        rating: starRating,
                        reviewText: finalText
                    )
                }
            }

            // Force recompute taste profile after new feedback data
            if let userId = AuthGuard.shared.currentUserId {
                await GWTasteEngine.shared.recompute(userId: userId.uuidString)
            }
        }

        showThankYou()
    }

    private func showThankYou() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            stage = .thankYou
        }

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
}

// MARK: - Watch Feedback Supabase Service

enum GWWatchFeedbackService {

    /// Upsert Stage 1 data to watch_feedback table
    static func upsertStage1(
        movieId: String,
        finished: Bool?,
        moodAfter: String,
        wouldPickAgain: Bool,
        timeOfDay: String,
        dayOfWeek: Int
    ) async {
        guard SupabaseConfig.isConfigured,
              let userId = AuthGuard.shared.currentUserId else { return }

        // movie_id in watch_feedback is INTEGER, extract from UUID string if needed
        guard let movieIdInt = extractMovieId(movieId) else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/watch_feedback?on_conflict=user_id,movie_id"
        guard let url = URL(string: urlString) else { return }

        let body: [String: Any] = [
            "user_id": userId.uuidString,
            "movie_id": movieIdInt,
            "finished": finished as Any,
            "mood_after": moodAfter,
            "would_pick_again": wouldPickAgain,
            "time_of_day": timeOfDay,
            "day_of_week": dayOfWeek,
        ]

        await postToSupabase(url: url, body: body)
    }

    /// Update Stage 2 data on existing watch_feedback row
    static func upsertStage2(
        movieId: String,
        feltComfort: Int,
        feltIntensity: Int,
        feltEnergy: Int,
        feltHumour: Int,
        satisfaction: Int?
    ) async {
        guard SupabaseConfig.isConfigured,
              let userId = AuthGuard.shared.currentUserId else { return }

        guard let movieIdInt = extractMovieId(movieId) else { return }

        // PATCH the existing row
        let urlString = "\(SupabaseConfig.url)/rest/v1/watch_feedback?user_id=eq.\(userId.uuidString)&movie_id=eq.\(movieIdInt)"
        guard let url = URL(string: urlString) else { return }

        var body: [String: Any] = [
            "felt_comfort": feltComfort,
            "felt_intensity": feltIntensity,
            "felt_energy": feltEnergy,
            "felt_humour": feltHumour,
        ]
        if let sat = satisfaction {
            body["satisfaction"] = sat
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            let (_, response) = try await URLSession.shared.data(for: request)
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("WatchFeedback Stage2: \(httpResponse.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("WatchFeedback Stage2 error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Helpers

    private static func extractMovieId(_ movieId: String) -> Int? {
        // movie_id might be a UUID string or an integer string
        if let intId = Int(movieId) {
            return intId
        }
        // If it's a UUID, we can't convert — the watch_feedback table uses INTEGER
        // The movie.id in Swift is UUID but tmdb_id or the Supabase row id is integer
        // For now, try to parse as int
        return nil
    }

    private static func postToSupabase(url: URL, body: [String: Any]) async {
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
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("WatchFeedback Stage1: \(httpResponse.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("WatchFeedback error: \(error.localizedDescription)")
            #endif
        }
    }
}

