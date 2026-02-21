import SwiftUI

// ============================================
// PICK CARD VIEW
// ============================================
// Individual card within the multi-pick carousel.
// Shows movie poster, title, GoodScore, position badge,
// Watch Now CTA, and X button for rejection.
//
// Layout:
// - Position badge (#1-#5) TOP-LEFT
// - X button TOP-RIGHT
// - Compact GoodScore box (48px) BOTTOM-LEFT
// - Title/metadata to right of GoodScore
// ============================================

struct PickCardView: View {
    let movie: Movie
    let gwMovie: GWMovie
    let goodScore: Int
    let position: Int           // 1-based position number
    let isTopPick: Bool         // true only for position 1 with original (non-replacement) movie
    let isReplacement: Bool     // true if this card replaced a rejected one
    let canReject: Bool         // false for replacement cards
    let userOTTs: [OTTPlatform]
    let userMood: String?
    let onWatchNow: (OTTProvider) -> Void
    let onReject: () -> Void    // triggers the 3D overlay

    @Environment(\.openURL) private var openURL

    // Animation states
    @State private var cardAppeared: Bool = false

    // MARK: - Provider Logic

    private var primaryProvider: OTTProvider? {
        movie.bestMatchingProvider(for: userOTTs)
    }

    // MARK: - "Why This" Copy

    private var whyThisCopy: String? {
        guard let mood = userMood?.lowercased() else { return nil }
        let movieTags = gwMovie.tags

        switch mood {
        case "feel-good", "feel_good", "feelgood":
            if movieTags.contains("feel_good") || movieTags.contains("uplifting") {
                return "Matches your feel-good mood."
            }
            return "Selected for your uplifting vibe."
        case "easy_watch", "easy watch", "light":
            return "Light and easy. Just what you wanted."
        case "surprise_me", "surprise me", "neutral":
            return "Our best pick for you."
        case "gripping", "intense":
            return "Gripping. You asked for it."
        case "dark_&_heavy", "dark & heavy", "dark":
            return "Dark and heavy. As requested."
        default:
            return nil
        }
    }

    var body: some View {
        ZStack {
            // Card background
            VStack(spacing: 0) {
                // Poster area
                ZStack(alignment: .bottom) {
                    // Movie poster
                    GWCachedImage(url: movie.posterURL(size: .w342)) {
                        posterSkeleton
                    }
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // Bottom gradient for text readability
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: GWColors.black.opacity(0.3), location: 0.3),
                            .init(color: GWColors.black.opacity(0.85), location: 0.7),
                            .init(color: GWColors.black, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                }

                // Content area: compact GoodScore box left, title/metadata right
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        // Compact GoodScore box (bottom-left, 48px)
                        VStack(spacing: 2) {
                            Text("\(goodScore)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient.goldGradient)

                            Text("GOODSCORE")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(GWColors.lightGray)
                                .tracking(1)
                        }
                        .frame(width: 48, height: 48)
                        .background(GWColors.darkGray)
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.sm)
                                .stroke(GWColors.gold.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(GWRadius.sm)

                        // Title + metadata to right of GoodScore
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(GWColors.white)
                                .lineLimit(2)

                            HStack(spacing: 4) {
                                if !movie.yearString.isEmpty {
                                    Text(movie.yearString)
                                }
                                Text(".")
                                Text(movie.runtimeDisplay)
                            }
                            .font(.system(size: 12))
                            .foregroundColor(GWColors.lightGray)

                            // Genre chips
                            if !movie.genreNames.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(movie.genreNames.prefix(2), id: \.self) { genre in
                                        Text(genre)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(GWColors.lightGray)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(GWColors.darkGray)
                                            .cornerRadius(GWRadius.sm)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // "Why This" copy
                    if let whyThis = whyThisCopy {
                        Text(whyThis)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GWColors.gold.opacity(0.9))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 8)

                    // Watch Now CTA
                    if let provider = primaryProvider {
                        Button {
                            openOTT(provider)
                            onWatchNow(provider)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("Watch on \(provider.displayName)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(GWColors.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(LinearGradient.goldGradient)
                            .cornerRadius(GWRadius.md)
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 12)
                }
                .padding(.top, -40) // Overlap with poster gradient
                .frame(maxWidth: .infinity)
                .background(GWColors.black)
            }

            // Position badge (TOP-LEFT)
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(position)")
                    .font(GWDesignTokens.positionBadgeFont)
                    .foregroundColor(GWColors.white)
                    .frame(width: GWDesignTokens.positionBadgeSize, height: GWDesignTokens.positionBadgeSize)
                    .background(GWColors.darkGray.opacity(0.9))
                    .cornerRadius(GWDesignTokens.positionBadgeSize / 2)

                if isTopPick {
                    Text("Top Pick")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GWColors.gold)
                } else if isReplacement && position == 1 {
                    Text("New Pick")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GWColors.gold)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 12)
            .padding(.leading, 12)

            // X button (TOP-RIGHT)
            if canReject {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GWColors.lightGray)
                        .frame(width: 28, height: 28)
                        .background(GWColors.black.opacity(0.7))
                        .cornerRadius(14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(GWColors.black)
        .cornerRadius(GWDesignTokens.pickCardCornerRadius)
        .shadow(color: .black.opacity(0.4), radius: GWDesignTokens.pickCardShadow, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: GWDesignTokens.pickCardCornerRadius)
                .stroke(GWColors.surfaceBorder, lineWidth: 1)
        )
        .scaleEffect(cardAppeared ? 1.0 : 0.95)
        .opacity(cardAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardAppeared = true
            }
        }
    }

    // MARK: - Poster Skeleton

    private var posterSkeleton: some View {
        Rectangle()
            .fill(GWColors.darkGray)
            .aspectRatio(2/3, contentMode: .fill)
            .overlay(
                ProgressView()
                    .tint(GWColors.lightGray)
            )
    }

    // MARK: - OTT Opener

    private func openOTT(_ provider: OTTProvider) {
        if let deepLink = provider.deepLinkURL {
            if UIApplication.shared.canOpenURL(deepLink) {
                openURL(deepLink)
                return
            }
        }
        if let webURL = provider.webURL {
            openURL(webURL)
        }
    }
}
