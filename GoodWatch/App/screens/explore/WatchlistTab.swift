import SwiftUI

// ============================================
// WATCHLIST TAB
// ============================================
// Shows saved movies from WatchlistManager
// Grid layout matching DiscoverTab style
// Includes filter chips (Genre, Language, Mood, Duration, Rating, Decade) + Sort

struct WatchlistTab: View {

    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var allMovies: [Movie] = []
    @State private var filteredMovies: [Movie] = []
    @State private var isLoading: Bool = false
    @State private var selectedMovie: Movie?
    @State private var lastFetchedIds: Set<String> = []
    @State private var fetchTask: Task<Void, Never>?

    // Filters
    @State private var activeGenres: Set<String> = []
    @State private var activeLanguages: Set<String> = []
    @State private var activeMoods: Set<String> = []
    @State private var activeDurations: Set<String> = []
    @State private var activeRatings: Set<String> = []
    @State private var activeDecades: Set<String> = []
    @State private var sortOption: SortOption = .ratingDesc

    // Sheet states
    @State private var showSortMenu: Bool = false
    @State private var showGenreFilter: Bool = false
    @State private var showLanguageFilter: Bool = false
    @State private var showMoodFilter: Bool = false
    @State private var showDurationFilter: Bool = false
    @State private var showRatingFilter: Bool = false
    @State private var showDecadeFilter: Bool = false

    private var hasActiveFilters: Bool {
        !activeGenres.isEmpty || !activeLanguages.isEmpty ||
        !activeMoods.isEmpty || !activeDurations.isEmpty ||
        !activeRatings.isEmpty || !activeDecades.isEmpty
    }

    private var activeFilterTags: [String] {
        var tags: [String] = []
        tags.append(contentsOf: activeGenres)
        tags.append(contentsOf: activeLanguages)
        tags.append(contentsOf: activeMoods)
        tags.append(contentsOf: activeDurations)
        tags.append(contentsOf: activeRatings)
        tags.append(contentsOf: activeDecades)
        return tags
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header count
            if !isLoading && !allMovies.isEmpty {
                HStack {
                    Text("\(filteredMovies.count) saved")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Filter chips
            filterChips

            // Active filters
            activeFiltersRow

            // Movie grid
            ScrollView {
                if isLoading {
                    loadingView
                } else if allMovies.isEmpty {
                    emptyView
                } else if filteredMovies.isEmpty && hasActiveFilters {
                    noResultsView
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(filteredMovies, id: \.id) { movie in
                            MovieGridCard(movie: movie, isInWatchlist: watchlist.isInWatchlist(movie.id.uuidString)) {
                                selectedMovie = movie
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .sheet(item: $selectedMovie) { movie in
                MovieDetailSheet(movie: movie)
            }
            .sheet(isPresented: $showSortMenu) {
                SortMenuSheet(selectedSort: $sortOption)
            }
            .sheet(isPresented: $showGenreFilter) {
                FilterSheet(title: "Genre", options: DiscoverViewModel.genreOptions, selected: $activeGenres)
            }
            .sheet(isPresented: $showLanguageFilter) {
                FilterSheet(title: "Language", options: DiscoverViewModel.languageOptions, selected: $activeLanguages)
            }
            .sheet(isPresented: $showMoodFilter) {
                FilterSheet(title: "Mood", options: DiscoverViewModel.moodOptions, selected: $activeMoods)
            }
            .sheet(isPresented: $showDurationFilter) {
                FilterSheet(title: "Duration", options: DiscoverViewModel.durationOptions, selected: $activeDurations)
            }
            .sheet(isPresented: $showRatingFilter) {
                FilterSheet(title: "Rating", options: DiscoverViewModel.ratingOptions, selected: $activeRatings)
            }
            .sheet(isPresented: $showDecadeFilter) {
                FilterSheet(title: "Decade", options: DiscoverViewModel.decadeOptions, selected: $activeDecades)
            }
        }
        .onAppear {
            fetchWatchlistMovies()
        }
        .onChange(of: watchlist.movieIds) { _ in
            fetchWatchlistMovies()
        }
        .onChange(of: activeGenres) { _ in applyFilters() }
        .onChange(of: activeLanguages) { _ in applyFilters() }
        .onChange(of: activeMoods) { _ in applyFilters() }
        .onChange(of: activeDurations) { _ in applyFilters() }
        .onChange(of: activeRatings) { _ in applyFilters() }
        .onChange(of: activeDecades) { _ in applyFilters() }
        .onChange(of: sortOption) { _ in applyFilters() }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort button (leftmost)
                Button {
                    showSortMenu.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                        Text("Sort")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(sortOption != .ratingDesc ? GWColors.gold : GWColors.lightGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(sortOption != .ratingDesc ? GWColors.gold.opacity(0.15) : GWColors.darkGray)
                    .cornerRadius(GWRadius.full)
                    .overlay(
                        RoundedRectangle(cornerRadius: GWRadius.full)
                            .stroke(sortOption != .ratingDesc ? GWColors.gold : GWColors.surfaceBorder, lineWidth: 1)
                    )
                }

                FilterChipButton(
                    title: activeGenres.isEmpty ? "Genre" : "Genre \u{00B7} \(activeGenres.count)",
                    isActive: !activeGenres.isEmpty,
                    action: { showGenreFilter.toggle() }
                )

                FilterChipButton(
                    title: activeLanguages.isEmpty ? "Language" : "Language \u{00B7} \(activeLanguages.count)",
                    isActive: !activeLanguages.isEmpty,
                    action: { showLanguageFilter.toggle() }
                )

                FilterChipButton(
                    title: activeMoods.isEmpty ? "Mood" : "Mood \u{00B7} \(activeMoods.count)",
                    isActive: !activeMoods.isEmpty,
                    action: { showMoodFilter.toggle() }
                )

                FilterChipButton(
                    title: activeDurations.isEmpty ? "Duration" : "Duration \u{00B7} \(activeDurations.count)",
                    isActive: !activeDurations.isEmpty,
                    action: { showDurationFilter.toggle() }
                )

                FilterChipButton(
                    title: activeRatings.isEmpty ? "Rating" : "Rating \u{00B7} \(activeRatings.count)",
                    isActive: !activeRatings.isEmpty,
                    action: { showRatingFilter.toggle() }
                )

                FilterChipButton(
                    title: activeDecades.isEmpty ? "Decade" : "Decade \u{00B7} \(activeDecades.count)",
                    isActive: !activeDecades.isEmpty,
                    action: { showDecadeFilter.toggle() }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Active Filters Row

    @ViewBuilder
    private var activeFiltersRow: some View {
        if hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(activeFilterTags, id: \.self) { tag in
                        ActiveFilterPill(
                            text: tag,
                            onRemove: { removeFilter(tag) }
                        )
                    }

                    Button("Clear all") {
                        clearAllFilters()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GWColors.gold)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Filter Methods

    private func clearAllFilters() {
        activeGenres.removeAll()
        activeLanguages.removeAll()
        activeMoods.removeAll()
        activeDurations.removeAll()
        activeRatings.removeAll()
        activeDecades.removeAll()
        applyFilters()
    }

    private func removeFilter(_ tag: String) {
        activeGenres.remove(tag)
        activeLanguages.remove(tag)
        activeMoods.remove(tag)
        activeDurations.remove(tag)
        activeRatings.remove(tag)
        activeDecades.remove(tag)
        applyFilters()
    }

    private func applyFilters() {
        var result = ClientMovieFilter.apply(
            to: allMovies,
            genres: activeGenres,
            languages: activeLanguages,
            moods: activeMoods,
            durations: activeDurations,
            ratings: activeRatings,
            decades: activeDecades
        )

        // Apply sort
        result = applySortOption(result, sortOption: sortOption)
        filteredMovies = result
    }

    private func applySortOption(_ movies: [Movie], sortOption: SortOption) -> [Movie] {
        switch sortOption {
        case .ratingDesc:
            return movies.sorted { ($0.goodScoreDisplay ?? 0) > ($1.goodScoreDisplay ?? 0) }
        case .ratingAsc:
            return movies.sorted { ($0.goodScoreDisplay ?? 0) < ($1.goodScoreDisplay ?? 0) }
        case .durationDesc:
            return movies.sorted { $0.runtimeMinutes > $1.runtimeMinutes }
        case .durationAsc:
            return movies.sorted { $0.runtimeMinutes < $1.runtimeMinutes }
        case .yearDesc:
            return movies.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .yearAsc:
            return movies.sorted { ($0.year ?? 0) < ($1.year ?? 0) }
        }
    }

    // MARK: - Fetch

    private func fetchWatchlistMovies() {
        let currentIds = watchlist.movieIds
        guard !currentIds.isEmpty else {
            allMovies = []
            filteredMovies = []
            lastFetchedIds = []
            return
        }

        // If an item was REMOVED, just filter locally -- no network needed
        if currentIds.isSubset(of: lastFetchedIds) && !lastFetchedIds.isEmpty {
            allMovies = allMovies.filter { currentIds.contains($0.id.uuidString) }
            lastFetchedIds = currentIds
            applyFilters()
            return
        }

        // Only fetch if new IDs were added
        fetchTask?.cancel()
        isLoading = allMovies.isEmpty  // Only show spinner if grid is empty

        fetchTask = Task {
            do {
                let fetched = try await ExploreService.shared.fetchMoviesByIds(Array(currentIds))
                await MainActor.run {
                    self.allMovies = fetched
                    self.lastFetchedIds = currentIds
                    self.isLoading = false
                    self.applyFilters()
                }
            } catch {
                #if DEBUG
                print("Error fetching watchlist movies: \(error)")
                #endif
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GWColors.gold)
                .scaleEffect(1.2)
            Text("Loading watchlist...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("Your watchlist is empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Tap the heart on any movie to save it here")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No matches")
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
