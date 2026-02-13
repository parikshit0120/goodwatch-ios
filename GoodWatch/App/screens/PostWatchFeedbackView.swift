import SwiftUI

// ============================================
// POST-WATCH FEEDBACK VIEW
// ============================================
//
// Shown when user returns to the app after clicking "Watch Now"
// and the feedback prompt is overdue (2+ hours later).
//
// Asks: "How was [Movie Title]?"
// Options: Finished it / Didn't finish / Skip
//
// On submit: Updates tag weights, logs to Supabase, clears blocking state.
// ============================================

struct PostWatchFeedbackView: View {
    let feedbackData: FeedbackPromptData
    let onCompleted: () -> Void
    let onAbandoned: () -> Void
    let onSkipped: () -> Void

    @State private var selectedOption: FeedbackOption? = nil
    @State private var isSubmitting = false

    enum FeedbackOption {
        case completed
        case abandoned
        case skipped
    }

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient.goldGradient)
                    .padding(.bottom, 24)

                // Main question
                Text(feedbackData.promptMessage)
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 8)

                // Sub-message
                Text(feedbackData.subMessage)
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 8)

                // Helper text
                Text("This helps us pick better for you next time.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(GWColors.lightGray.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 40)

                // Option buttons
                VStack(spacing: 12) {
                    // Finished it — primary CTA
                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        selectedOption = .completed
                        onCompleted()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Finished it")
                                .font(GWTypography.button())
                        }
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient.goldGradient)
                        .cornerRadius(GWRadius.lg)
                        .opacity(isSubmitting && selectedOption != .completed ? 0.5 : 1.0)
                    }

                    // Didn't finish — secondary
                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        selectedOption = .abandoned
                        onAbandoned()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "stop.circle")
                                .font(.system(size: 20))
                            Text("Didn't finish")
                                .font(GWTypography.button())
                        }
                        .foregroundColor(GWColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.md)
                                .stroke(GWColors.surfaceBorder, lineWidth: 1.5)
                        )
                        .cornerRadius(GWRadius.md)
                        .opacity(isSubmitting && selectedOption != .abandoned ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 20)

                // Divider
                Rectangle()
                    .fill(GWColors.surfaceBorder)
                    .frame(height: 1)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 16)

                // Skip
                Button {
                    guard !isSubmitting else { return }
                    isSubmitting = true
                    selectedOption = .skipped
                    onSkipped()
                } label: {
                    Text("Skip")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }

                Spacer()
            }
        }
    }
}
