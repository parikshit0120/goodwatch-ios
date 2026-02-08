import SwiftUI

// Screen 5: Confidence Moment (Transition)
// "Finding your film..." with animated gold dots
// Duration: 1.0 - 1.2 seconds
struct ConfidenceMomentView: View {
    let onComplete: () -> Void

    @State private var dot1Scale: CGFloat = 1.0
    @State private var dot2Scale: CGFloat = 1.0
    @State private var dot3Scale: CGFloat = 1.0
    @State private var dot1Opacity: Double = 0.3
    @State private var dot2Opacity: Double = 0.3
    @State private var dot3Opacity: Double = 0.3
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
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

                // Text
                Text("Finding your film...")
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.lightGray)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
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
