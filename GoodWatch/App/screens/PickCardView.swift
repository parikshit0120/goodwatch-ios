import SwiftUI
import SafariServices

// ============================================
// PICK CARD VIEW
// ============================================
// Individual card within the multi-pick carousel.
// v1.3 HOTFIX: Applies FIX 3-10 to match MainScreenView design.
//
// Layout:
// - Position badge (#1-#5) TOP-LEFT
// - Content type badge (Movie/Series) TOP-CENTER
// - X button TOP-RIGHT
// - Play trailer button CENTER of poster
// - Compact GoodScore box BOTTOM-LEFT
// - Title/metadata to right of GoodScore
// - Genre badges row
// - Truncated summary + "more" link
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
    let trailerKey: String?     // YouTube video key (FIX 10). Nil = no trailer.
    let onWatchNow: (OTTProvider) -> Void
    let onReject: () -> Void    // triggers the 3D overlay

    @Environment(\.openURL) private var openURL

    // Animation states
    @State private var cardAppeared: Bool = false

    // Full summary popup (FIX 9)
    @State private var showFullSummary: Bool = false

    // MARK: - Provider Logic

    private var primaryProvider: OTTProvider? {
        movie.bestMatchingProvider(for: userOTTs)
    }

    // MARK: - "Why This" Copy (Rank-Based)

    private var whyThisCopy: String {
        switch position {
        case 1: return "Top pick."
        case 2: return "Runner up."
        case 3: return "Also great."
        case 4: return "Worth a watch."
        default: return "Dark horse."
        }
    }

    // MARK: - Summary Truncation (FIX 8)

    private func truncatedOverview(_ text: String, maxWords: Int = 20) -> (text: String, isTruncated: Bool) {
        let words = text.split(separator: " ")
        if words.count <= maxWords { return (text, false) }
        return (words.prefix(maxWords).joined(separator: " ") + "...", true)
    }

    var body: some View {
        ZStack {
            // Card background
            VStack(spacing: 0) {
                // Poster area
                ZStack {
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

                    // Content type badge — TOP CENTER (FIX 4)
                    VStack {
                        Text(movie.contentTypeLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(GWColors.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GWColors.gold)
                            .cornerRadius(GWRadius.sm)
                            .padding(.top, 10)
                        Spacer()
                    }

                    // Play button HIDDEN: trailer playback not yet properly implemented.
                    // Will re-enable once in-app trailer player is built.
                }

                // Content area: compact GoodScore box left, title/metadata right
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        // Compact GoodScore box
                        VStack(spacing: 2) {
                            Text("\(goodScore)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient.goldGradient)

                            Text("GOODSCORE")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(GWColors.lightGray)
                                .tracking(1.2)
                                .fixedSize()
                        }
                        .frame(minWidth: 64, minHeight: 48)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
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

                            // Genre badges row (FIX 7) — first 3 genres as compact pills
                            let displayGenres = Array(movie.genreNames.prefix(3))
                            if !displayGenres.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(displayGenres, id: \.self) { genre in
                                        Text(genre)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(GWColors.lightGray)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: GWRadius.sm)
                                                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
                                            )
                                            .cornerRadius(GWRadius.sm)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Rank-based "Why This" copy
                    Text(whyThisCopy)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GWColors.gold.opacity(0.9))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    // Summary: truncated to ~20 words + "more" link (FIX 8, 9)
                    if let overview = movie.overview, !overview.isEmpty {
                        let result = truncatedOverview(overview)
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(result.text)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(GWColors.lightGray.opacity(0.85))
                            if result.isTruncated {
                                Text(" ")
                                Button("more") {
                                    showFullSummary = true
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(GWColors.gold)
                            }
                        }
                        .lineLimit(3)
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

                if isReplacement && position == 1 {
                    Text("New Pick")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GWColors.gold)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 12)
            .padding(.leading, 12)

            // X button (TOP-RIGHT) — FIX 3: no overlap with badge (badge is now top-center)
            if canReject {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
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
        .onAppear {
            if !cardAppeared {
                cardAppeared = true
            }
        }
        .sheet(isPresented: $showFullSummary) {
            // Full storyline popup (FIX 9)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(movie.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(GWColors.white)
                    Spacer()
                    Button(action: { showFullSummary = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(GWColors.lightGray)
                            .font(.system(size: 24))
                    }
                }

                ScrollView {
                    Text(movie.overview ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(GWColors.white)
                        .lineSpacing(6)
                }
            }
            .padding(20)
            .background(GWColors.darkGray)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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

    // MARK: - OTT Opener (FIX 5: uses universal links for Prime Video)

    private func openOTT(_ provider: OTTProvider) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "gw_screenshot_mode") { return }
        #endif
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

    // MARK: - Trailer Playback (FIX 10)

    private func playTrailer() {
        guard let key = trailerKey else { return }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "gw_screenshot_mode") { return }
        #endif
        let youtubeAppURL = URL(string: "youtube://www.youtube.com/watch?v=\(key)")!
        let youtubeWebURL = URL(string: "https://www.youtube.com/watch?v=\(key)")!

        if UIApplication.shared.canOpenURL(youtubeAppURL) {
            openURL(youtubeAppURL)
        } else {
            openURL(youtubeWebURL)
        }
    }
}
