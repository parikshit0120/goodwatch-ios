import SwiftUI

// ============================================
// NEW RELEASES TAB
// ============================================
// List-style view of recent movies with platform filtering

struct NewReleasesTab: View {

    @StateObject private var viewModel = NewReleasesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Platform filter tabs
            platformFilterTabs

            // Content type filter (Movies / Series / Documentary)
            contentTypeFilter

            // Sort dropdown
            sortRow

            // Movie list
            movieList
        }
    }

    // MARK: - Platform Filter Tabs

    private var platformFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PlatformFilterButton(
                    title: "All",
                    count: viewModel.totalCount,
                    isSelected: viewModel.selectedPlatform == nil,
                    action: { viewModel.selectedPlatform = nil }
                )

                ForEach(NewReleasesViewModel.platforms, id: \.self) { platform in
                    PlatformFilterButton(
                        title: platform,
                        count: viewModel.platformCounts[platform] ?? 0,
                        isSelected: viewModel.selectedPlatform == platform,
                        action: { viewModel.selectedPlatform = platform }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Content Type Filter

    private var contentTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                ContentTypeChip(
                    title: "All",
                    isSelected: viewModel.selectedContentType == nil,
                    action: { viewModel.selectedContentType = nil }
                )

                ForEach(NewReleasesViewModel.contentTypes, id: \.self) { type in
                    ContentTypeChip(
                        title: type,
                        isSelected: viewModel.selectedContentType == type,
                        action: { viewModel.selectedContentType = type }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    // MARK: - Sort Row

    private var sortRow: some View {
        HStack {
            Button {
                viewModel.showSortMenu.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text(viewModel.sortOption.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(GWColors.lightGray)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(GWColors.darkGray)
                .cornerRadius(GWRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.full)
                        .stroke(GWColors.surfaceBorder, lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Movie List

    private var movieList: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.movies.isEmpty {
                loadingView
            } else if viewModel.movies.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.movies, id: \.id) { movie in
                        MovieListCard(movie: movie) {
                            viewModel.selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $viewModel.selectedMovie) { movie in
            MovieDetailSheet(movie: movie)
        }
        .sheet(isPresented: $viewModel.showSortMenu) {
            SortMenuSheet(selectedSort: $viewModel.sortOption)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GWColors.gold)
                .scaleEffect(1.2)
            Text("Loading new releases...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No new releases")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Check back soon for updates")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Platform Filter Button

struct PlatformFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? GWColors.black : GWColors.lightGray)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? GWColors.gold : GWColors.darkGray)
            .cornerRadius(GWRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: GWRadius.md)
                    .stroke(isSelected ? Color.clear : GWColors.surfaceBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Movie List Card

struct MovieListCard: View {
    let movie: Movie
    var showRentalProviders: Bool = false
    let onTap: () -> Void

    private var isNew: Bool {
        guard let year = movie.year else { return false }
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Poster thumbnail
                ZStack(alignment: .topLeading) {
                    if let url = movie.posterURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                posterPlaceholder
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(2/3, contentMode: .fill)
                                    .frame(width: 78, height: 112)
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

                    // NEW badge
                    if isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(GWColors.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(GWColors.gold)
                            .cornerRadius(GWRadius.sm)
                            .padding(5)
                    }
                }
                .frame(width: 78, height: 112)
                .cornerRadius(GWRadius.md)
                .clipped()

                // Movie info
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(movie.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(GWColors.white)
                        .lineLimit(2)

                    // GoodScore + metadata
                    HStack(spacing: 6) {
                        if let score = movie.goodScoreDisplay {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(GWColors.gold)
                                Text("\(score)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(GWColors.white)
                            }
                        }

                        if !movie.yearString.isEmpty {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(GWColors.lightGray)
                            Text(movie.yearString)
                                .font(.system(size: 11))
                                .foregroundColor(GWColors.lightGray)
                        }

                        if movie.runtimeMinutes > 0 {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(GWColors.lightGray)
                            Text(movie.runtimeDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(GWColors.lightGray)
                        }
                    }

                    // Language
                    if let lang = movie.original_language {
                        Text(lang.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GWColors.lightGray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GWColors.darkGray)
                            .cornerRadius(GWRadius.sm)
                    }

                    // Genres
                    if !movie.genreNames.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(movie.genreNames.prefix(3), id: \.self) { genre in
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

                    Spacer()

                    // Platform badges — hidden in Rent tab (redundant since user already filtered by platform)
                    if !showRentalProviders {
                        let uniqueNames = deduplicatedPlatformNames(for: movie)
                        if !uniqueNames.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(uniqueNames.prefix(3), id: \.self) { name in
                                    Text(name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(Color.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(platformGradient(for: name))
                                        .cornerRadius(GWRadius.sm)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(GWColors.darkGray)
            .cornerRadius(GWRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: GWRadius.md)
                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(GWColors.darkGray)
            .frame(width: 78, height: 112)
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundColor(GWColors.lightGray.opacity(0.5))
            )
    }

    private func deduplicatedPlatformNames(for movie: Movie) -> [String] {
        let providers = showRentalProviders ? movie.rentalProviders : movie.supportedProviders
        var seen = Set<String>()
        var result: [String] = []
        for provider in providers {
            let name = provider.displayName
            if !seen.contains(name) {
                seen.insert(name)
                result.append(name)
            }
        }
        return result
    }

    private func platformGradient(for name: String) -> LinearGradient {
        let lowered = name.lowercased()
        if lowered.contains("netflix") {
            return LinearGradient(colors: [Color(hex: "E50914"), Color(hex: "B20710")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("prime") || lowered == "amazon" {
            return LinearGradient(colors: [Color(hex: "00A8E1"), Color(hex: "0086B3")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("hotstar") {
            return LinearGradient(colors: [Color(hex: "1F80E0"), Color(hex: "1660B0")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("apple tv") {
            return LinearGradient(colors: [Color(hex: "a2a2a2"), Color(hex: "808080")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("zee5") {
            return LinearGradient(colors: [Color(hex: "8230C6"), Color(hex: "6620A0")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("sony") {
            return LinearGradient(colors: [Color(hex: "555555"), Color(hex: "333333")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("google play") {
            return LinearGradient(colors: [Color(hex: "01875F"), Color(hex: "01664A")], startPoint: .top, endPoint: .bottom)
        }
        if lowered.contains("youtube") {
            return LinearGradient(colors: [Color(hex: "FF0000"), Color(hex: "CC0000")], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [GWColors.lightGray, GWColors.lightGray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Content Type Chip

struct ContentTypeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? GWColors.black : GWColors.lightGray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? GWColors.gold : Color.clear)
                .cornerRadius(GWRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.full)
                        .stroke(isSelected ? Color.clear : GWColors.surfaceBorder, lineWidth: 1)
                )
        }
    }
}
