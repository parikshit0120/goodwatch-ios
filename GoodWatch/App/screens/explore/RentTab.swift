import SwiftUI

// ============================================
// RENT TAB
// ============================================
// List-style view of movies available to rent or buy
// across Apple TV, Google Play, YouTube, Amazon Video

struct RentTab: View {

    @StateObject private var viewModel = RentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Platform filter tabs
            platformFilterTabs

            // Filter chips (Sort + Genre, Language, Mood, Duration, Rating, Decade)
            filterChips

            // Active filters
            activeFiltersRow

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

                ForEach(RentViewModel.platforms, id: \.self) { platform in
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

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort button (leftmost)
                Button {
                    viewModel.showSortMenu.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                        Text("Sort")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(viewModel.sortOption != .ratingDesc ? GWColors.gold : GWColors.lightGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(viewModel.sortOption != .ratingDesc ? GWColors.gold.opacity(0.15) : GWColors.darkGray)
                    .cornerRadius(GWRadius.full)
                    .overlay(
                        RoundedRectangle(cornerRadius: GWRadius.full)
                            .stroke(viewModel.sortOption != .ratingDesc ? GWColors.gold : GWColors.surfaceBorder, lineWidth: 1)
                    )
                }

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

                FilterChipButton(
                    title: viewModel.activeMoods.isEmpty ? "Mood" : "Mood \u{00B7} \(viewModel.activeMoods.count)",
                    isActive: !viewModel.activeMoods.isEmpty,
                    action: { viewModel.showMoodFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeDurations.isEmpty ? "Duration" : "Duration \u{00B7} \(viewModel.activeDurations.count)",
                    isActive: !viewModel.activeDurations.isEmpty,
                    action: { viewModel.showDurationFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeRatings.isEmpty ? "Rating" : "Rating \u{00B7} \(viewModel.activeRatings.count)",
                    isActive: !viewModel.activeRatings.isEmpty,
                    action: { viewModel.showRatingFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeDecades.isEmpty ? "Decade" : "Decade \u{00B7} \(viewModel.activeDecades.count)",
                    isActive: !viewModel.activeDecades.isEmpty,
                    action: { viewModel.showDecadeFilter.toggle() }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
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
            .padding(.top, 8)
        }
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
                        MovieListCard(movie: movie, showRentalProviders: true) {
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
        .sheet(isPresented: $viewModel.showGenreFilter) {
            FilterSheet(title: "Genre", options: DiscoverViewModel.genreOptions, selected: $viewModel.activeGenres)
        }
        .sheet(isPresented: $viewModel.showLanguageFilter) {
            FilterSheet(title: "Language", options: DiscoverViewModel.languageOptions, selected: $viewModel.activeLanguages)
        }
        .sheet(isPresented: $viewModel.showMoodFilter) {
            FilterSheet(title: "Mood", options: DiscoverViewModel.moodOptions, selected: $viewModel.activeMoods)
        }
        .sheet(isPresented: $viewModel.showDurationFilter) {
            FilterSheet(title: "Duration", options: DiscoverViewModel.durationOptions, selected: $viewModel.activeDurations)
        }
        .sheet(isPresented: $viewModel.showRatingFilter) {
            FilterSheet(title: "Rating", options: DiscoverViewModel.ratingOptions, selected: $viewModel.activeRatings)
        }
        .sheet(isPresented: $viewModel.showDecadeFilter) {
            FilterSheet(title: "Decade", options: DiscoverViewModel.decadeOptions, selected: $viewModel.activeDecades)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GWColors.gold)
                .scaleEffect(1.2)
            Text("Loading rentals...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No rentals available")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Rental data is being synced -- check back soon")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
