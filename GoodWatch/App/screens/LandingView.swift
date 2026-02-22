import SwiftUI

// Screen 0: Landing View
// Simple: Logo + Wordmark + Tagline
// Clean home screen — archetype card lives in Profile tab only
struct LandingView: View {
    let onContinue: () -> Void
    var onExplore: (() -> Void)?
    var onProfileTap: (() -> Void)?
    var onDebugSkip: (() -> Void)?  // DEBUG: skip to recommendation with preset context

    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var posterImages: [Int: Image] = [:]
    @State private var postersReady: Bool = false

    // Explore button is always visible — auth gate is inside ExploreView

    // Hardcoded TMDB poster paths for landing background grid
    // All live-action movies — NO animated films
    // 32 posters = 8 rows × 4 columns to fill the full screen
    private let backdropPosters: [String] = [
        "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg",  // Live-action
        "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg",  // Live-action
        "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",  // Fight Club
        "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",  // Live-action
        "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",  // The Dark Knight
        "/rCzpDGLbOoPwLjy3OAm5NUPOTrC.jpg",  // Live-action
        "/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg",  // Live-action
        "/ty8TGRuvJLPUmAR1H1nRIsgwvim.jpg",  // Gladiator
        "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",  // Live-action
        "/sv1xJUazXeYqALzczSZ3O6nkH75.jpg",  // Live-action
        "/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",  // The Shawshank Redemption
        "/62HCnUTziyWcpDaBO2i1DX17ljH.jpg",  // Live-action
        "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",  // Parasite
        "/6CoRTJTmijhBLJTUNoVSUNxZMEI.jpg",  // Live-action
        "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",  // Live-action
        "/ngl2FKBlU4fhbdsrtdom9LVLBXw.jpg",  // Live-action
        "/t6HIqrRAclMCA60NsSmeqe9RmNV.jpg",  // Live-action
        "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",  // Oppenheimer
        "/rktDFPbfHfUbArZ6OOOKsXcv0Bm.jpg",  // Live-action
        "/saHP97rTPS5eLmrLQEcANmKrsFl.jpg",  // Forrest Gump
        "/wWJbBo5yjw22AIjE8isBFoiBI3S.jpg",  // The Godfather
        "/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg",  // Inception
        "/lBYOKAMcxIvuk9s9hMuecB9dPBV.jpg",  // The Pursuit of Happyness
        "/bAKvH3yDzEHG0kTwQ6HbCCCpYhh.jpg",  // Life is Beautiful
        "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg",  // Duplicate row for coverage
        "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg",
        "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
        "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        "/rCzpDGLbOoPwLjy3OAm5NUPOTrC.jpg",
        "/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg",
        "/ty8TGRuvJLPUmAR1H1nRIsgwvim.jpg",
        "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
    ]

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            // Poster grid background — tilted collage for cinematic feel
            GeometryReader { geo in
                let columns = 4
                let spacing: CGFloat = 6
                let posterW = (geo.size.width + 40) / CGFloat(columns) - spacing
                let posterH: CGFloat = 110

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(posterW), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(0..<backdropPosters.count, id: \.self) { i in
                        if let img = posterImages[i] {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: posterW, height: posterH)
                                .clipped()
                                .cornerRadius(6)
                        } else {
                            // Dark placeholder — matches grid, never empty
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: posterW, height: posterH)
                        }
                    }
                }
                .padding(-20)
                .rotationEffect(.degrees(-8))
                .scaleEffect(1.2)
                .opacity(postersReady ? 0.55 : 0.15)
                .animation(.easeOut(duration: 0.5), value: postersReady)
            }
            .ignoresSafeArea()

            // Vertical gradient over poster grid — fades bottom for text legibility (STRONGER)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: GWColors.black.opacity(0.2), location: 0),
                    .init(color: GWColors.black.opacity(0.5), location: 0.3),
                    .init(color: GWColors.black.opacity(0.85), location: 0.55),
                    .init(color: GWColors.black.opacity(0.98), location: 0.75),
                    .init(color: GWColors.black, location: 0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // DEBUG: Quick-skip button (top-right, only in debug builds)
                #if DEBUG
                HStack {
                    Spacer()
                    if let debugSkip = onDebugSkip {
                        Button(action: debugSkip) {
                            Image(systemName: "ant.fill")
                                .font(.system(size: 14))
                                .foregroundColor(GWColors.lightGray.opacity(0.5))
                                .padding(8)
                                .background(GWColors.darkGray.opacity(0.6))
                                .cornerRadius(8)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                }
                #endif

                Spacer().frame(height: 100)

                // Logo (Golden film strip) - 30% smaller
                AppLogo(size: 112)
                    .opacity(logoOpacity)

                Spacer().frame(height: 24)

                // Wordmark - 20% larger
                Text("GoodWatch")
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(LinearGradient.goldGradient)
                    .opacity(textOpacity)

                Spacer().frame(height: 12)

                // Tagline
                VStack(spacing: 4) {
                    Text("Stop browsing.")
                    Text("Start watching.")
                }
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.lightGray)
                .opacity(textOpacity)

                Spacer()

                // Recent Picks — compact poster thumbnails for visual recall
                recentPicksSection

                // Bottom action area
                VStack(spacing: 14) {
                    // Primary CTA
                    Button(action: onContinue) {
                        Text("Pick for me")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(GWColors.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient.goldGradient)
                            .cornerRadius(30)
                    }
                    .accessibilityIdentifier("landing_pick_for_me")

                    // Explore / Search button — always visible, auth gate inside ExploreView
                    if let explore = onExplore {
                        Button(action: explore) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Explore & Search")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(GWColors.lightGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GWColors.darkGray)
                            .cornerRadius(30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
                            )
                        }
                        .accessibilityIdentifier("landing_explore")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1
            }
            // Preload all poster images concurrently, then reveal together
            preloadPosters()
        }
    }

    // MARK: - Recent Picks Section

    @ViewBuilder
    private var recentPicksSection: some View {
        let recentPicks = RecentPicksService.shared.getPicks()
        if !recentPicks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Picks")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GWColors.lightGray)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentPicks) { pick in
                            RecentPickCard(pick: pick)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            .opacity(textOpacity)
        }
    }

    // MARK: - Poster Preloading

    private func preloadPosters() {
        Task {
            var loaded: [Int: Image] = [:]
            let concurrency = 4 // Throttle: max 4 concurrent downloads

            // Process in batches to avoid 32 simultaneous URLSession requests
            for batchStart in stride(from: 0, to: backdropPosters.count, by: concurrency) {
                let batchEnd = min(batchStart + concurrency, backdropPosters.count)
                let batch = Array(batchStart..<batchEnd)

                await withTaskGroup(of: (Int, Image?).self) { group in
                    for index in batch {
                        let path = backdropPosters[index]
                        group.addTask {
                            let urlString = TMDBImageSize.url(path: path, size: .w154)
                            if let uiImage = await GWImageCache.shared.loadImage(from: urlString) {
                                return (index, Image(uiImage: uiImage))
                            }
                            return (index, nil)
                        }
                    }
                    for await (index, image) in group {
                        if let image = image {
                            loaded[index] = image
                        }
                    }
                }
            }

            // Update all at once on main thread (single state update)
            await MainActor.run {
                posterImages = loaded
                withAnimation(.easeOut(duration: 0.6)) {
                    postersReady = true
                }
            }
        }
    }
}

// MARK: - Recent Pick Card

struct RecentPickCard: View {
    let pick: RecentPicksService.RecentPick

    var body: some View {
        VStack(spacing: 6) {
            // Poster thumbnail
            if let urlString = pick.posterURL {
                GWCachedImage(url: urlString) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GWColors.darkGray)
                        .frame(width: 80, height: 120)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipped()
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(GWColors.darkGray)
                    .frame(width: 80, height: 120)
            }

            // Title (1 line)
            Text(pick.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GWColors.white)
                .lineLimit(1)
                .frame(width: 80)

            // GoodScore
            Text("\(pick.goodScore)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LinearGradient.goldGradient)
        }
    }
}

// MARK: - User Archetype

struct UserArchetype {
    let name: String        // e.g. "The Comfort Seeker"
    let emoji: String       // e.g. "🎬"
    let description: String // e.g. "You lean toward feel-good, easy watches"
    let traits: [String]    // e.g. ["Feel-good", "Light", "Safe picks"]

    static func derive(from weights: [String: Double]) -> UserArchetype {
        // Find dominant emotional outcome
        let emotionalOutcomes: [(String, String)] = [
            ("feel_good", "feel-good"), ("uplifting", "uplifting"),
            ("dark", "dark"), ("disturbing", "intense"), ("bittersweet", "bittersweet")
        ]
        let energyLevels: [(String, String)] = [
            ("calm", "calm"), ("tense", "gripping"), ("high_energy", "high-energy")
        ]
        let cogLevels: [(String, String)] = [
            ("light", "easy"), ("medium", "balanced"), ("heavy", "deep")
        ]
        let riskLevels: [(String, String)] = [
            ("safe_bet", "safe picks"), ("polarizing", "varied picks"), ("acquired_taste", "adventurous")
        ]

        func topWeight(_ pairs: [(String, String)]) -> (String, String, Double) {
            var best = pairs[0]
            var bestW = weights[pairs[0].0] ?? 1.0
            for pair in pairs {
                let w = weights[pair.0] ?? 1.0
                if w > bestW {
                    best = pair
                    bestW = w
                }
            }
            return (best.0, best.1, bestW)
        }

        let (emotionKey, emotionLabel, _) = topWeight(emotionalOutcomes)
        let (_, energyLabel, _) = topWeight(energyLevels)
        let (_, cogLabel, _) = topWeight(cogLevels)
        let (riskKey, riskLabel, _) = topWeight(riskLevels)

        // Determine archetype name
        let name: String
        let emoji: String
        switch emotionKey {
        case "feel_good", "uplifting":
            if riskKey == "safe_bet" {
                name = "The Comfort Seeker"
                emoji = "☀️"
            } else {
                name = "The Optimist"
                emoji = "🌈"
            }
        case "dark", "disturbing":
            name = "The Deep Diver"
            emoji = "🌊"
        case "bittersweet":
            name = "The Film Buff"
            emoji = "🎬"
        default:
            name = "The Explorer"
            emoji = "🧭"
        }

        let desc = "You lean toward \(emotionLabel), \(cogLabel) watches"
        let traits = [emotionLabel.capitalized, energyLabel.capitalized, riskLabel.capitalized]

        return UserArchetype(name: name, emoji: emoji, description: desc, traits: traits)
    }
}

