import SwiftUI

// ============================================
// MOVIE GRID CARD - 3-column grid card
// ============================================

struct MovieGridCard: View {
    let movie: Movie
    let onTap: () -> Void

    @ObservedObject private var watchlist = WatchlistManager.shared

    private var isInWatchlist: Bool {
        watchlist.isInWatchlist(movie.id.uuidString)
    }

    private var isNew: Bool {
        guard let year = movie.year else { return false }
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1
    }

    /// Deduplicated platform display names (e.g. "Amazon Prime Video" and "Amazon Prime Video with Ads" both → "Prime Video")
    private var uniquePlatformNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for provider in movie.supportedProviders {
            let name = provider.displayName
            if !seen.contains(name) {
                seen.insert(name)
                result.append(name)
            }
        }
        return result
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Poster with badges
                ZStack(alignment: .topTrailing) {
                    if let url = movie.posterURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                posterPlaceholder
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(2/3, contentMode: .fill)
                                    .clipped()
                            case .failure:
                                posterPlaceholder
                            @unknown default:
                                posterPlaceholder
                            }
                        }
                    } else {
                        posterPlaceholder
                    }

                    // Top-right: Rating badge + Heart button stacked
                    VStack(spacing: 4) {
                        // Heart button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                watchlist.toggle(movie.id.uuidString)
                            }
                        } label: {
                            Image(systemName: isInWatchlist ? "heart.fill" : "heart")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isInWatchlist ? Color(hex: "FF4D6A") : GWColors.white)
                                .shadow(color: .black.opacity(0.6), radius: 3)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // GoodScore badge (0-100 scale)
                        if let score = movie.goodScoreDisplay {
                            Text("\(score)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(GWColors.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(GWColors.gold)
                                .cornerRadius(GWRadius.sm)
                        }
                    }
                    .padding(6)

                    // NEW badge
                    if isNew {
                        VStack {
                            HStack {
                                Text("NEW")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundColor(GWColors.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(GWColors.gold)
                                    .cornerRadius(GWRadius.sm)
                                    .padding(6)
                                Spacer()
                            }
                            Spacer()
                            // Runtime badge
                            if movie.runtimeMinutes > 0 {
                                HStack {
                                    Text(movie.runtimeDisplay)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(GWColors.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(GWRadius.sm)
                                        .padding(6)
                                    Spacer()
                                }
                            }
                        }
                    } else if movie.runtimeMinutes > 0 {
                        // Runtime badge (bottom-left)
                        VStack {
                            Spacer()
                            HStack {
                                Text(movie.runtimeDisplay)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(GWColors.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(GWRadius.sm)
                                    .padding(6)
                                Spacer()
                            }
                        }
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .cornerRadius(GWRadius.md)
                .clipped()

                // Title
                Text(movie.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(GWColors.white)
                    .lineLimit(1)

                // Metadata
                HStack(spacing: 4) {
                    if !movie.yearString.isEmpty {
                        Text(movie.yearString)
                            .font(.system(size: 10))
                            .foregroundColor(GWColors.lightGray)
                    }
                    if !movie.yearString.isEmpty && movie.original_language != nil {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(GWColors.lightGray)
                    }
                    if let lang = movie.original_language {
                        Text(lang.uppercased())
                            .font(.system(size: 10))
                            .foregroundColor(GWColors.lightGray)
                    }
                }

                // Platform dots (deduplicated by platform name)
                if !uniquePlatformNames.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(uniquePlatformNames.prefix(4), id: \.self) { name in
                            Circle()
                                .fill(platformColor(for: name))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(GWColors.darkGray)
            .aspectRatio(2/3, contentMode: .fit)
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 20))
                    .foregroundColor(GWColors.lightGray.opacity(0.5))
            )
    }

    private func platformColor(for name: String) -> Color {
        let lowered = name.lowercased()
        if lowered.contains("netflix") { return Color(hex: "E50914") }
        if lowered.contains("prime") || lowered == "amazon" { return Color(hex: "00A8E1") }
        if lowered.contains("hotstar") { return Color(hex: "1F80E0") }
        if lowered.contains("apple tv") { return Color(hex: "a2a2a2") }
        if lowered.contains("zee5") { return Color(hex: "8230C6") }
        if lowered.contains("sony") { return Color(hex: "555555") }
        if lowered.contains("google play") { return Color(hex: "01875F") }
        if lowered.contains("youtube") { return Color(hex: "FF0000") }
        return GWColors.lightGray
    }
}
