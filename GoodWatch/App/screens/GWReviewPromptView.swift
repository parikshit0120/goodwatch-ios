import SwiftUI

// ============================================
// UGC REVIEW PROMPT — Post-Watch Rating
// ============================================
//
// Modal overlay shown after user taps "Watch Now" and returns to the app.
// - 5-star rating (gold stars, tap to select)
// - Optional text review (max 280 chars)
// - Submit sends to user_reviews table in Supabase
// - Skip dismisses without submitting
// - Triggers: shown from EnjoyScreen after Watch Now acceptance
// ============================================

struct GWReviewPromptView: View {
    let movieTitle: String
    let movieId: String
    let onSubmit: (Int, String?) -> Void   // (rating, optional review text)
    let onSkip: () -> Void

    @State private var selectedRating: Int = 0
    @State private var reviewText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showThankYou: Bool = false

    // Animation
    @State private var appearOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Tap outside = skip
                    onSkip()
                }

            if showThankYou {
                thankYouContent
                    .transition(.scale.combined(with: .opacity))
            } else {
                reviewCard
                    .scaleEffect(cardScale)
                    .opacity(appearOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appearOpacity = 1
                cardScale = 1
            }
        }
    }

    // MARK: - Review Card

    private var reviewCard: some View {
        VStack(spacing: 20) {
            // Header
            Text("How was it?")
                .font(GWTypography.headline())
                .foregroundColor(GWColors.white)

            Text(movieTitle)
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.lightGray)
                .lineLimit(1)

            // Star Rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundStyle(star <= selectedRating ? LinearGradient.goldGradient : LinearGradient(colors: [GWColors.lightGray], startPoint: .top, endPoint: .bottom))
                        .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectedRating)
                        .onTapGesture {
                            selectedRating = star
                        }
                }
            }
            .padding(.vertical, 8)

            // Rating label
            if selectedRating > 0 {
                Text(ratingLabel(selectedRating))
                    .font(GWTypography.small(weight: .medium))
                    .foregroundColor(GWColors.gold)
                    .transition(.opacity)
            }

            // Optional text review
            if selectedRating > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("Share a quick thought (optional)", text: $reviewText, axis: .vertical)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Buttons
            VStack(spacing: 12) {
                // Submit button (only active with rating)
                Button {
                    submitReview()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(GWColors.black)
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                            .font(GWTypography.button())
                            .foregroundColor(GWColors.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedRating > 0 ? LinearGradient.goldGradient : LinearGradient(colors: [GWColors.lightGray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(GWRadius.lg)
                }
                .disabled(selectedRating == 0 || isSubmitting || reviewText.count > 280)

                // Skip button
                Button {
                    MetricsService.shared.track(.reviewSkipped, properties: ["movie_id": movieId])
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }
            }
        }
        .padding(24)
        .background(GWColors.darkGray)
        .cornerRadius(GWRadius.xl)
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }

    // MARK: - Thank You

    private var thankYouContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.goldGradient)

            Text("Thanks for your review!")
                .font(GWTypography.headline())
                .foregroundColor(GWColors.white)

            Text("Your taste helps us improve picks for everyone.")
                .font(GWTypography.body())
                .foregroundColor(GWColors.lightGray)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(GWColors.darkGray)
        .cornerRadius(GWRadius.xl)
        .padding(.horizontal, 24)
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

    private func submitReview() {
        guard selectedRating > 0 else { return }
        isSubmitting = true

        let trimmedText = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText: String? = trimmedText.isEmpty ? nil : String(trimmedText.prefix(280))

        // Track the review submission
        MetricsService.shared.track(.reviewSubmitted, properties: [
            "movie_id": movieId,
            "rating": selectedRating,
            "has_text": finalText != nil
        ])

        // Show thank you then submit
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showThankYou = true
        }

        // Submit to Supabase
        onSubmit(selectedRating, finalText)

        // Auto-dismiss after thank you
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onSkip()
        }
    }
}

// MARK: - Review Submission Service

enum GWReviewService {

    /// Submit a user review to the user_reviews Supabase table
    static func submitReview(userId: String, movieId: String, rating: Int, reviewText: String?) async {
        guard SupabaseConfig.isConfigured else { return }

        let urlString = "\(SupabaseConfig.url)/rest/v1/user_reviews?on_conflict=user_id,movie_id"
        guard let url = URL(string: urlString) else { return }

        var body: [String: Any] = [
            "user_id": userId,
            "movie_id": movieId,
            "rating": rating,
            "is_public": true
        ]
        if let text = reviewText {
            body["review_text"] = text
        }

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
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("GWReview: Review submitted (rating: \(rating), movie: \(movieId))")
                } else {
                    print("GWReview: Submit failed with status \(httpResponse.statusCode)")
                }
            }
            #endif
        } catch {
            #if DEBUG
            print("GWReview: Submit error: \(error.localizedDescription)")
            #endif
        }
    }
}
