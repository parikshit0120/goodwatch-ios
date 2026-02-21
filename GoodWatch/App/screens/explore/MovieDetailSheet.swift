import SwiftUI

// ============================================
// MOVIE DETAIL SHEET - Bottom sheet modal
// ============================================

struct MovieDetailSheet: View {
    let movie: Movie

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var watchlist = WatchlistManager.shared

    private var isInWatchlist: Bool {
        watchlist.isInWatchlist(movie.id.uuidString)
    }

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Backdrop area
                    backdropArea

                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and rating
                        titleSection

                        // Overview
                        if let overview = movie.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(GWColors.lightGray)
                                .lineSpacing(4)
                        }

                        // Genres
                        if !movie.genreNames.isEmpty {
                            genreSection
                        }

                        // Director and Cast
                        if movie.directorDisplay != nil || movie.castDisplay != nil {
                            creditsSection
                        }

                        // Watch On section
                        if !movie.supportedProviders.isEmpty {
                            watchOnSection
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Top overlay: Heart + Close buttons
            VStack {
                HStack {
                    // Heart / Watchlist button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            watchlist.toggle(movie.id.uuidString)
                        }
                    } label: {
                        Image(systemName: isInWatchlist ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isInWatchlist ? Color(hex: "FF4D6A") : GWColors.white.opacity(0.9))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .blur(radius: 4)
                            )
                    }
                    .padding(20)

                    Spacer()

                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(GWColors.white.opacity(0.9))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .blur(radius: 4)
                            )
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Backdrop Area

    private var backdropArea: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            GWCachedImage(url: movie.posterURL(size: .w500)) {
                Rectangle()
                    .fill(GWColors.darkGray)
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: 250)
            .clipped()
            .blur(radius: 8)
            .brightness(-0.3)

            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, GWColors.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 250)

            // Poster and metadata
            HStack(alignment: .bottom, spacing: 14) {
                // Poster
                GWCachedImage(url: movie.posterURL(size: .w342)) {
                    Rectangle().fill(Color.clear)
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 100)
                .cornerRadius(GWRadius.md)
                .shadow(color: .black.opacity(0.5), radius: 12)

                // Runtime pill
                VStack(alignment: .leading, spacing: 6) {
                    if movie.runtimeMinutes > 0 {
                        Text(movie.runtimeDisplay)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(GWColors.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(GWColors.gold.opacity(0.2))
                            .cornerRadius(GWRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: GWRadius.sm)
                                    .stroke(GWColors.gold, lineWidth: 1)
                            )
                    }

                    Spacer()
                }
                .frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 250)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movie.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(GWColors.white)

            HStack(spacing: 8) {
                // GoodScore (0-100)
                if let score = movie.goodScoreDisplay {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GWColors.gold)
                        Text("\(score)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(GWColors.white)
                    }
                }

                if !movie.yearString.isEmpty {
                    Text("·")
                        .foregroundColor(GWColors.lightGray)
                    Text(movie.yearString)
                        .font(.system(size: 14))
                        .foregroundColor(GWColors.lightGray)
                }

                if let lang = movie.original_language {
                    Text("·")
                        .foregroundColor(GWColors.lightGray)
                    Text(lang.uppercased())
                        .font(.system(size: 14))
                        .foregroundColor(GWColors.lightGray)
                }
            }
        }
    }

    // MARK: - Genre Section

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GWColors.lightGray)
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: 6) {
                ForEach(movie.genreNames.prefix(5), id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GWColors.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(GWColors.darkGray)
                        .cornerRadius(GWRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.sm)
                                .stroke(GWColors.surfaceBorder, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Credits Section

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let director = movie.directorDisplay {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Director")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GWColors.lightGray)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(director)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GWColors.white)
                }
            }

            if let cast = movie.castDisplay {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cast")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GWColors.lightGray)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(cast)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GWColors.white)
                }
            }
        }
    }

    // MARK: - Watch On Section

    private var watchOnSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch On")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GWColors.lightGray)
                .textCase(.uppercase)
                .tracking(1)

            ForEach(Array(uniqueProviders.enumerated()), id: \.offset) { _, provider in
                Button {
                    openProvider(provider)
                } label: {
                    HStack(spacing: 12) {
                        Text(provider.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white)

                        Spacer()

                        // Type badge (Rent / Buy / Stream)
                        if let type = provider.type {
                            Text(typeBadgeLabel(type))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(GWRadius.sm)
                        }

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(platformGradient(for: provider.displayName))
                    .cornerRadius(GWRadius.md)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func openProvider(_ provider: OTTProvider) {
        // Try deep link first, fall back to web URL
        if let deepLink = provider.deepLinkURL {
            openURL(deepLink) { accepted in
                if !accepted, let web = provider.webURL {
                    openURL(web)
                }
            }
        } else if let web = provider.webURL {
            openURL(web)
        }
    }

    private func typeBadgeLabel(_ type: String) -> String {
        switch type {
        case "rent": return "RENT"
        case "buy": return "BUY"
        case "flatrate": return "STREAM"
        case "ads": return "FREE"
        default: return type.uppercased()
        }
    }

    // MARK: - Helpers

    /// One row per platform — prefers stream over rent over buy.
    /// e.g. Apple TV appears once (not separate RENT + BUY rows).
    private var uniqueProviders: [OTTProvider] {
        var seen = Set<String>()
        var result: [OTTProvider] = []
        let typeOrder: [String: Int] = ["flatrate": 0, "ads": 1, "rent": 2, "buy": 3]
        let sorted = movie.supportedProviders.sorted {
            (typeOrder[$0.type ?? "flatrate"] ?? 4) < (typeOrder[$1.type ?? "flatrate"] ?? 4)
        }
        for provider in sorted {
            let key = provider.displayName.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(provider)
            }
        }
        return Array(result.prefix(6))
    }

    private func platformGradient(for name: String) -> LinearGradient {
        let lowered = name.lowercased()
        if lowered.contains("netflix") {
            return LinearGradient(colors: [Color(hex: "E50914"), Color(hex: "B20710")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("prime") || lowered == "amazon" {
            return LinearGradient(colors: [Color(hex: "00A8E1"), Color(hex: "0086B3")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("hotstar") {
            return LinearGradient(colors: [Color(hex: "1F80E0"), Color(hex: "1660B0")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("apple tv") {
            return LinearGradient(colors: [Color(hex: "a2a2a2"), Color(hex: "808080")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("zee5") {
            return LinearGradient(colors: [Color(hex: "8230C6"), Color(hex: "6620A0")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("sony") {
            return LinearGradient(colors: [Color(hex: "555555"), Color(hex: "333333")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("google play") {
            return LinearGradient(colors: [Color(hex: "01875F"), Color(hex: "01664A")], startPoint: .leading, endPoint: .trailing)
        }
        if lowered.contains("youtube") {
            return LinearGradient(colors: [Color(hex: "FF0000"), Color(hex: "CC0000")], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [GWColors.lightGray, GWColors.lightGray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
    }
}
