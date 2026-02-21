import SwiftUI

// ============================================
// DISCOVER TAB
// ============================================
// Search, filters, sort, and grid view

struct DiscoverTab: View {

    @StateObject private var viewModel = DiscoverViewModel()
    @ObservedObject private var watchlist = WatchlistManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Filter chips (Sort first)
            filterChips

            // Active filters
            activeFiltersRow

            // Movie grid
            movieGrid
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(GWColors.gold)
                .font(.system(size: 16, weight: .medium))

            TextField("Search movies, actors, directors...", text: $viewModel.searchQuery)
                .foregroundColor(GWColors.white)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GWColors.lightGray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(GWColors.darkGray)
        .cornerRadius(GWRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.lg)
                .stroke(GWColors.gold.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort button (FIRST — leftmost)
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
                    title: viewModel.activeGenres.isEmpty ? "Genre" : "Genre · \(viewModel.activeGenres.count)",
                    isActive: !viewModel.activeGenres.isEmpty,
                    action: { viewModel.showGenreFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeLanguages.isEmpty ? "Language" : "Language · \(viewModel.activeLanguages.count)",
                    isActive: !viewModel.activeLanguages.isEmpty,
                    action: { viewModel.showLanguageFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeMoods.isEmpty ? "Mood" : "Mood · \(viewModel.activeMoods.count)",
                    isActive: !viewModel.activeMoods.isEmpty,
                    action: { viewModel.showMoodFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeDurations.isEmpty ? "Duration" : "Duration · \(viewModel.activeDurations.count)",
                    isActive: !viewModel.activeDurations.isEmpty,
                    action: { viewModel.showDurationFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeRatings.isEmpty ? "Rating" : "Rating · \(viewModel.activeRatings.count)",
                    isActive: !viewModel.activeRatings.isEmpty,
                    action: { viewModel.showRatingFilter.toggle() }
                )

                FilterChipButton(
                    title: viewModel.activeDecades.isEmpty ? "Decade" : "Decade · \(viewModel.activeDecades.count)",
                    isActive: !viewModel.activeDecades.isEmpty,
                    action: { viewModel.showDecadeFilter.toggle() }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
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
            .padding(.top, 10)
        }
    }

    // MARK: - Movie Grid

    private var movieGrid: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.movies.isEmpty {
                loadingView
            } else if viewModel.movies.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(viewModel.movies, id: \.id) { movie in
                        MovieGridCard(movie: movie, isInWatchlist: watchlist.isInWatchlist(movie.id.uuidString)) {
                            viewModel.selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $viewModel.selectedMovie) { movie in
            MovieDetailSheet(movie: movie)
        }
        .sheet(isPresented: $viewModel.showGenreFilter) {
            FilterSheet(
                title: "Genre",
                options: DiscoverViewModel.genreOptions,
                selected: $viewModel.activeGenres
            )
        }
        .sheet(isPresented: $viewModel.showLanguageFilter) {
            FilterSheet(
                title: "Language",
                options: DiscoverViewModel.languageOptions,
                selected: $viewModel.activeLanguages
            )
        }
        .sheet(isPresented: $viewModel.showMoodFilter) {
            FilterSheet(
                title: "Mood",
                options: DiscoverViewModel.moodOptions,
                selected: $viewModel.activeMoods
            )
        }
        .sheet(isPresented: $viewModel.showDurationFilter) {
            FilterSheet(
                title: "Duration",
                options: DiscoverViewModel.durationOptions,
                selected: $viewModel.activeDurations
            )
        }
        .sheet(isPresented: $viewModel.showRatingFilter) {
            FilterSheet(
                title: "Rating",
                options: DiscoverViewModel.ratingOptions,
                selected: $viewModel.activeRatings
            )
        }
        .sheet(isPresented: $viewModel.showDecadeFilter) {
            FilterSheet(
                title: "Decade",
                options: DiscoverViewModel.decadeOptions,
                selected: $viewModel.activeDecades
            )
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
            Text("Loading movies...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No movies found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Try adjusting your filters")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Filter Chip Button

struct FilterChipButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? GWColors.gold : GWColors.lightGray)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? GWColors.gold.opacity(0.15) : GWColors.darkGray)
                .cornerRadius(GWRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.full)
                        .stroke(isActive ? GWColors.gold : GWColors.surfaceBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Active Filter Pill

struct ActiveFilterPill: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .medium))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundColor(GWColors.gold)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(GWColors.gold.opacity(0.15))
        .cornerRadius(GWRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.sm)
                .stroke(GWColors.gold.opacity(0.4), lineWidth: 1)
        )
    }
}
