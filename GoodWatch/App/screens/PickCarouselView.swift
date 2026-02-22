import SwiftUI

// ============================================
// PICK CAROUSEL VIEW
// ============================================
// Stacked card carousel for the multi-pick experience.
// Shows N movies (5 to 1) based on user's interaction points tier.
// Each card has Watch Now + X button. Rejected cards are replaced once.
//
// Layout:
// - Center card is full-size
// - Adjacent cards peek from edges, scaled down and dimmed
// - Infinite horizontal scroll (wraps around)
// - Paging dots below
// - Subtle progress text when pickCount > 1
// ============================================

struct PickCarouselView: View {
    let picks: [GWMovie]
    let rawMovies: [Movie]  // For looking up Movie from GWMovie
    let pickCount: Int
    let replacedPositions: Set<Int>
    let userOTTs: [OTTPlatform]
    let userMood: String?
    let onWatchNow: (Movie, OTTProvider) -> Void
    let onReject: (GWMovie, GWCardRejectionReason) -> Void
    let onStartOver: () -> Void
    let onExplore: (() -> Void)?

    @State private var currentIndex: Int = 0
    @State private var flippedIndex: Int? = nil  // Which card is showing rejection overlay
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                AppLogo(size: 26)

                Text("GoodWatch")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient.goldGradient)

                Spacer()

                if let explore = onExplore {
                    Button(action: explore) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(GWColors.lightGray)
                    }
                }

                Button(action: onStartOver) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GWColors.lightGray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Divider
            Rectangle()
                .fill(GWColors.surfaceBorder)
                .frame(height: 1)

            // Carousel
            GeometryReader { geometry in
                let cardWidth = geometry.size.width * (1.0 - 2 * GWDesignTokens.pickCardPeekRatio)
                let spacing: CGFloat = 8

                ZStack {
                    ForEach(picks.indices, id: \.self) { index in
                        let offset = cardOffset(for: index, cardWidth: cardWidth, spacing: spacing)
                        let scale = cardScale(for: index)
                        let opacity = cardOpacity(for: index)

                        cardContent(at: index)
                            .frame(width: cardWidth)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .offset(x: offset + dragOffset * (index == currentIndex ? 1.0 : 0.6))
                            .zIndex(index == currentIndex ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = cardWidth * 0.25
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if value.translation.width < -threshold {
                                    // Swipe left -> next card
                                    currentIndex = (currentIndex + 1) % picks.count
                                } else if value.translation.width > threshold {
                                    // Swipe right -> previous card
                                    currentIndex = (currentIndex - 1 + picks.count) % picks.count
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .padding(.top, 8)

            // Paging dots
            if picks.count > 1 {
                HStack(spacing: GWDesignTokens.progressDotSpacing) {
                    ForEach(0..<picks.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? GWColors.gold : GWColors.lightGray.opacity(0.4))
                            .frame(width: GWDesignTokens.progressDotSize, height: GWDesignTokens.progressDotSize)
                    }
                }
                .padding(.top, 12)
            }

            // Progress text (only when pickCount > 1)
            if pickCount > 1 {
                Text("Picks are narrowing as we learn the taste")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(GWColors.lightGray.opacity(0.6))
                    .padding(.top, 6)
            }

            Spacer().frame(height: 16)
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private func cardContent(at index: Int) -> some View {
        let gwMovie = picks[index]
        let movie = rawMovies.first(where: { $0.id.uuidString == gwMovie.id })

        if let movie = movie {
            if flippedIndex == index {
                // Show rejection overlay
                RejectionOverlayView(
                    movie: movie,
                    onNotInterested: {
                        flippedIndex = nil
                        onReject(gwMovie, .notInterested)
                    },
                    onAlreadySeen: {
                        flippedIndex = nil
                        onReject(gwMovie, .alreadySeen)
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: GWDesignTokens.rejectionFlipDuration)) {
                            flippedIndex = nil
                        }
                    }
                )
            } else {
                PickCardView(
                    movie: movie,
                    gwMovie: gwMovie,
                    goodScore: computeGoodScore(gwMovie),
                    position: index + 1,
                    isTopPick: index == 0 && !replacedPositions.contains(index),
                    isReplacement: replacedPositions.contains(index),
                    canReject: GWFeatureFlags.shared.isEnabled("card_rejection") && !replacedPositions.contains(index),
                    userOTTs: userOTTs,
                    userMood: userMood,
                    onWatchNow: { provider in
                        onWatchNow(movie, provider)
                    },
                    onReject: {
                        withAnimation(.easeInOut(duration: GWDesignTokens.rejectionFlipDuration)) {
                            flippedIndex = index
                        }
                    }
                )
            }
        } else {
            // Fallback if movie lookup fails
            RoundedRectangle(cornerRadius: GWDesignTokens.pickCardCornerRadius)
                .fill(GWColors.darkGray)
                .overlay(
                    Text("Loading...")
                        .font(GWTypography.body())
                        .foregroundColor(GWColors.lightGray)
                )
        }
    }

    // MARK: - Carousel Geometry

    private func cardOffset(for index: Int, cardWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let diff = index - currentIndex
        // Handle wrapping
        let adjustedDiff: Int
        if abs(diff) > picks.count / 2 {
            if diff > 0 {
                adjustedDiff = diff - picks.count
            } else {
                adjustedDiff = diff + picks.count
            }
        } else {
            adjustedDiff = diff
        }
        return CGFloat(adjustedDiff) * (cardWidth + spacing)
    }

    private func cardScale(for index: Int) -> CGFloat {
        index == currentIndex ? 1.0 : GWDesignTokens.pickCardScaleAdjacent
    }

    private func cardOpacity(for index: Int) -> Double {
        index == currentIndex ? 1.0 : GWDesignTokens.pickCardDimAdjacent
    }

    // MARK: - Helpers

    private func computeGoodScore(_ gwMovie: GWMovie) -> Int {
        if gwMovie.composite_score > 0 {
            return Int(round(gwMovie.composite_score))
        }
        return Int(round(gwMovie.goodscore * 10))
    }
}
