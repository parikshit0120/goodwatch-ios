import SwiftUI

// Screen 5: Confidence Moment (Transition)
// "Finding your film..." with animated gold dots + movie trivia
// Duration: ~1.2 seconds (auto-completes)
struct ConfidenceMomentView: View {
    let onComplete: () -> Void

    @State private var dot1Scale: CGFloat = 1.0
    @State private var dot2Scale: CGFloat = 1.0
    @State private var dot3Scale: CGFloat = 1.0
    @State private var dot1Opacity: Double = 0.3
    @State private var dot2Opacity: Double = 0.3
    @State private var dot3Opacity: Double = 0.3
    @State private var textOpacity: Double = 0
    @State private var triviaOpacity: Double = 0

    // Movie trivia — shown during the wait so it doesn't feel like a wait
    private let trivia: [String] = [
        "The longest movie ever made is over 35 days long.",
        "The first film ever made was just 2 seconds long.",
        "A movie set's \"best boy\" has nothing to do with acting.",
        "There are over 500,000 movies in existence worldwide.",
        "India produces the most films per year of any country.",
        "The Wilhelm Scream has been used in over 400 films.",
        "Psycho was the first film to show a toilet flushing.",
        "The average Hollywood movie makes 80% of its profit overseas.",
        "Sean Connery wore a toupee in every Bond film.",
        "The word \"movie\" comes from \"moving picture.\"",
        "Hitchcock's Rope was designed to look like one continuous shot.",
        "Most car sounds in films are added in post-production.",
        "Film reels used to be flammable and caused theater fires.",
        "The average movie script is about 120 pages long.",
        "Disney almost went bankrupt before Snow White saved them."
    ]

    private var randomTrivia: String {
        trivia[Int.random(in: 0..<trivia.count)]
    }

    @State private var currentTrivia: String = ""

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Animated gold dots
                HStack(spacing: 8) {
                    Circle()
                        .fill(GWColors.gold)
                        .frame(width: 12, height: 12)
                        .scaleEffect(dot1Scale)
                        .opacity(dot1Opacity)

                    Circle()
                        .fill(GWColors.gold)
                        .frame(width: 12, height: 12)
                        .scaleEffect(dot2Scale)
                        .opacity(dot2Opacity)

                    Circle()
                        .fill(GWColors.gold)
                        .frame(width: 12, height: 12)
                        .scaleEffect(dot3Scale)
                        .opacity(dot3Opacity)
                }

                // Finding text
                Text("Finding your film...")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.lightGray)
                    .opacity(textOpacity)

                Spacer()

                // Movie trivia at the bottom
                VStack(spacing: 8) {
                    Text("Did you know?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GWColors.gold)
                        .tracking(1.2)

                    Text(currentTrivia)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                }
                .opacity(triviaOpacity)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            currentTrivia = randomTrivia
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in text
        withAnimation(.easeOut(duration: 0.3)) {
            textOpacity = 1
        }

        // Animate dots in sequence with pulse effect
        animateDots()

        // Fade in trivia after a brief pause
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            triviaOpacity = 1
        }

        // Complete after ~1.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onComplete()
        }
    }

    private func animateDots() {
        // Dot 1 pulse
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            dot1Scale = 1.2
            dot1Opacity = 1.0
        }

        // Dot 2 pulse (delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                dot2Scale = 1.2
                dot2Opacity = 1.0
            }
        }

        // Dot 3 pulse (more delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                dot3Scale = 1.2
                dot3Opacity = 1.0
            }
        }
    }
}
