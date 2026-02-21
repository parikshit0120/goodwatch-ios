import SwiftUI

// ============================================
// UPCOMING RELEASES TAB
// ============================================
// Two sections: "Upcoming in Theatres" and "Upcoming on OTTs"
// Uses upcoming_releases Supabase table.
// OTT section items cross-reference the movies table for ratings.
// Same visual design as NewReleasesTab (list cards, platform badges, GoodScore).

struct UpcomingReleasesTab: View {

    @StateObject private var viewModel = UpcomingReleasesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Section toggle (Theatres / OTT)
            sectionToggle

            // Platform filter (OTT section only)
            if viewModel.selectedSection == .ott {
                platformFilterTabs
            }

            // Content type filter
            contentTypeFilter

            // Filter chips (Genre, Language)
            filterChips

            // Active filters
            activeFiltersRow

            // Movie list
            movieList
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipButton(
                    title: viewModel.activeGenres.isEmpty ? "Genre" : "Genre \u{00B7} \(viewModel.activeGenres.count)",
                    isActive: !viewModel.activeGenres.isEmpty,
                    action: { viewModel.showGenreFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeLanguages.isEmpty ? "Language" : "Language \u{00B7} \(viewModel.activeLanguages.count)",
                    isActive: !viewModel.activeLanguages.isEmpty,
                    action: { viewModel.showLanguageFilter.toggle() }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    // MARK: - Active Filters Row

    @ViewBuilder
    private var activeFiltersRow: some View {
        if viewModel.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.activeFilterTags, id: \.self) { tag in
                        ActiveFilterPill(
                            text: tag,
                            onRemove: { viewModel.removeFilter(tag) }
                        )
                    }

                    Button("Clear all") {
                        viewModel.clearAllFilters()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GWColors.gold)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Section Toggle

    private var sectionToggle: some View {
        HStack(spacing: 0) {
            ForEach(UpcomingReleasesViewModel.Section.allCases, id: \.self) { section in
                Button {
                    viewModel.selectedSection = section
                } label: {
                    Text("\(section.displayName) (\(viewModel.sectionCounts[section] ?? 0))")
                        .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(viewModel.selectedSection == section ? GWColors.black : GWColors.lightGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.selectedSection == section ? GWColors.gold : GWColors.darkGray)
                }
            }
        }
        .cornerRadius(GWRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.md)
                .stroke(GWColors.surfaceBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Platform Filter Tabs (OTT only)

    private var platformFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PlatformFilterButton(
                    title: "All",
                    count: viewModel.sectionCounts[.ott] ?? 0,
                    isSelected: viewModel.selectedPlatform == nil,
                    action: { viewModel.selectedPlatform = nil }
                )

                ForEach(UpcomingReleasesViewModel.ottPlatforms, id: \.self) { platform in
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
        .padding(.top, 6)
    }

    // MARK: - Content Type Filter

    private var contentTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ContentTypeChip(
                    title: "All",
                    isSelected: viewModel.selectedContentType == nil,
                    action: { viewModel.selectedContentType = nil }
                )

                ForEach(UpcomingReleasesViewModel.contentTypes, id: \.self) { type in
                    ContentTypeChip(
                        title: type,
                        isSelected: viewModel.selectedContentType == type,
                        action: { viewModel.selectedContentType = type }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }

    // MARK: - Movie List

    private var movieList: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items, id: \.id) { item in
                        UpcomingListCard(item: item, enrichedMovie: viewModel.enrichedMovies[item.tmdb_id]) {
                            if let movie = viewModel.enrichedMovies[item.tmdb_id] {
                                viewModel.selectedMovie = movie
                            }
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
        .sheet(isPresented: $viewModel.showGenreFilter) {
            FilterSheet(title: "Genre", options: UpcomingReleasesViewModel.genres, selected: $viewModel.activeGenres)
        }
        .sheet(isPresented: $viewModel.showLanguageFilter) {
            FilterSheet(title: "Language", options: DiscoverViewModel.languageOptions, selected: $viewModel.activeLanguages)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GWColors.gold)
                .scaleEffect(1.2)
            Text("Loading upcoming releases...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No upcoming releases")
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

// MARK: - Upcoming List Card

struct UpcomingListCard: View {
    let item: UpcomingRelease
    let enrichedMovie: Movie?
    let onTap: () -> Void

    private var formattedDate: String {
        guard let date = item.release_date else { return "TBD" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy"
        return display.string(from: d)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Poster thumbnail
                GWCachedImage(url: item.poster_path.flatMap { TMDBImageSize.url(path: $0, size: .w154) }) {
                    posterPlaceholder
                }
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 78, height: 112)
                .cornerRadius(GWRadius.md)
                .clipped()

                // Movie info
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(GWColors.white)
                        .lineLimit(2)

                    // GoodScore (from enriched movie if available) + release date
                    HStack(spacing: 6) {
                        if let movie = enrichedMovie, let score = movie.goodScoreDisplay {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(GWColors.gold)
                                Text("\(score)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(GWColors.white)
                            }
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(GWColors.lightGray)
                        }

                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(GWColors.lightGray)
                        Text(formattedDate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GWColors.lightGray)
                    }

                    // Language
                    if !item.original_language.isEmpty {
                        Text(item.original_language.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GWColors.lightGray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GWColors.darkGray)
                            .cornerRadius(GWRadius.sm)
                    }

                    // Genres
                    if let genres = item.genreNames, !genres.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(genres.prefix(3), id: \.self) { genre in
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

                    // Platform badge (for OTT items)
                    if item.section == "ott", let platform = item.platform {
                        HStack(spacing: 4) {
                            Text(platform)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(platformGradient(for: platform))
                                .cornerRadius(GWRadius.sm)

                            Text("Coming Soon")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(GWColors.gold)
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
        return LinearGradient(colors: [GWColors.lightGray, GWColors.lightGray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Genre Chip

struct GenreChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? GWColors.gold : GWColors.lightGray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? GWColors.gold.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.md)
                        .stroke(isSelected ? GWColors.gold : GWColors.surfaceBorder, lineWidth: 1)
                )
                .cornerRadius(GWRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
