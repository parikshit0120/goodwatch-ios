import SwiftUI

// ============================================
// REJECTION OVERLAY VIEW
// ============================================
// 3D card flip overlay shown when user taps X on a pick card.
// The card rotates around the Y-axis to reveal two rejection options
// on the "back": "Not for me" and "Already seen".
//
// Animation:
// 1. Card rotates 0 -> 90 degrees (ease-in, 0.25s)
// 2. At 90 degrees, swap front for back content
// 3. Card rotates 90 -> 0 degrees (ease-out, 0.25s)
// 4. Back shows dimmed poster + blur + two buttons + cancel
// ============================================

struct RejectionOverlayView: View {
    let movie: Movie
    let onNotInterested: () -> Void
    let onAlreadySeen: () -> Void
    let onCancel: () -> Void

    @State private var isFlipped: Bool = false
    @State private var showingBack: Bool = false
    @State private var selectedOption: GWCardRejectionReason? = nil

    var body: some View {
        ZStack {
            if !showingBack {
                // Front face (will be hidden during flip)
                frontFace
                    .opacity(isFlipped ? 0 : 1)
            } else {
                // Back face
                backFace
                    .rotation3DEffect(
                        .degrees(showingBack ? 0 : -90),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
        }
        .rotation3DEffect(
            .degrees(isFlipped && !showingBack ? 90 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onAppear {
            // Start flip animation
            withAnimation(.easeIn(duration: 0.25)) {
                isFlipped = true
            }

            // At midpoint, swap to back face
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showingBack = true
                withAnimation(.easeOut(duration: 0.25)) {
                    // Back face rotates into view
                }
            }
        }
    }

    // MARK: - Front Face (placeholder, mostly invisible during animation)

    private var frontFace: some View {
        RoundedRectangle(cornerRadius: GWDesignTokens.pickCardCornerRadius)
            .fill(GWColors.darkGray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Back Face

    private var backFace: some View {
        ZStack {
            // Dimmed poster background
            GWCachedImage(url: movie.posterURL(size: .w342)) {
                Rectangle().fill(GWColors.darkGray)
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Blur + dim overlay
            Rectangle()
                .fill(GWColors.black.opacity(0.75))
                .background(.ultraThinMaterial)

            // Buttons
            VStack(spacing: 16) {
                Spacer()

                Text(movie.title)
                    .font(GWTypography.body(weight: .semibold))
                    .foregroundColor(GWColors.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 8)

                // "Not for me" button
                Button {
                    handleSelection(.notInterested)
                } label: {
                    Text("Not for me")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedOption == .notInterested ? GWColors.black : GWColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GWDesignTokens.rejectionButtonHeight)
                        .background(
                            selectedOption == .notInterested
                                ? AnyShapeStyle(LinearGradient.goldGradient)
                                : AnyShapeStyle(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.md)
                                .stroke(GWColors.lightGray.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(GWRadius.md)
                }
                .padding(.horizontal, 24)

                // "Already seen" button
                Button {
                    handleSelection(.alreadySeen)
                } label: {
                    Text("Already seen")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedOption == .alreadySeen ? GWColors.black : GWColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GWDesignTokens.rejectionButtonHeight)
                        .background(
                            selectedOption == .alreadySeen
                                ? AnyShapeStyle(LinearGradient.goldGradient)
                                : AnyShapeStyle(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.md)
                                .stroke(GWColors.lightGray.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(GWRadius.md)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 8)

                // Cancel — flip back
                Button(action: onCancel) {
                    Text("Never mind")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                }

                Spacer()
            }
        }
        .cornerRadius(GWDesignTokens.pickCardCornerRadius)
    }

    // MARK: - Selection Handler

    private func handleSelection(_ reason: GWCardRejectionReason) {
        selectedOption = reason

        // Brief gold flash then trigger callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch reason {
            case .notInterested:
                onNotInterested()
            case .alreadySeen:
                onAlreadySeen()
            }
        }
    }
}
