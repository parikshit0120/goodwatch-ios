import SwiftUI
import Combine

// ============================================
// DISCOVER VIEW MODEL
// ============================================

@MainActor
class DiscoverViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var searchQuery: String = ""
    @Published var movies: [Movie] = []
    @Published var isLoading: Bool = false
    @Published var totalResults: Int = 0
    @Published var selectedMovie: Movie?

    // Filters
    @Published var activeGenres: Set<String> = []
    @Published var activeLanguages: Set<String> = []
    @Published var activeMoods: Set<String> = []
    @Published var activeDurations: Set<String> = []
    @Published var activeRatings: Set<String> = []
    @Published var activeDecades: Set<String> = []

    // Sheet states
    @Published var showGenreFilter: Bool = false
    @Published var showLanguageFilter: Bool = false
    @Published var showMoodFilter: Bool = false
    @Published var showDurationFilter: Bool = false
    @Published var showRatingFilter: Bool = false
    @Published var showDecadeFilter: Bool = false
    @Published var showSortMenu: Bool = false

    // Sort
    @Published var sortOption: SortOption = .ratingDesc

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 0
    private let pageSize = 30

    // MARK: - Initialization

    init() {
        setupSearchDebounce()
        fetchMovies()
    }

    // MARK: - Filter Options

    static let genreOptions = [
        "Action", "Comedy", "Drama", "Thriller", "Romance",
        "Horror", "Sci-Fi", "Crime", "Animation", "Documentary"
    ]

    static let languageOptions = [
        "English", "Hindi", "Japanese", "Tamil", "Telugu", "Malayalam",
        "Spanish", "Korean", "Kannada", "Bengali", "Marathi", "French",
        "Chinese", "Portuguese", "Punjabi", "Gujarati"
    ]

    static let moodOptions = [
        "Feel-good", "Intense", "Dark", "Light-hearted",
        "Edge-of-seat", "Inspirational", "Fun", "Epic",
        "Wild", "Gripping", "Visceral", "Emotional"
    ]

    static let durationOptions = [
        "Under 90 min", "90–150 min", "150+ min", "Epic 180+"
    ]

    static let ratingOptions = [
        "6+", "7+", "8+"
    ]

    static let decadeOptions = [
        "2020s", "2010s", "2000s", "90s", "80s", "Classic"
    ]

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        !activeGenres.isEmpty || !activeLanguages.isEmpty ||
        !activeMoods.isEmpty || !activeDurations.isEmpty ||
        !activeRatings.isEmpty || !activeDecades.isEmpty
    }

    var activeFilterTags: [String] {
        var tags: [String] = []
        tags.append(contentsOf: activeGenres.map { $0 })
        tags.append(contentsOf: activeLanguages.map { $0 })
        tags.append(contentsOf: activeMoods.map { $0 })
        tags.append(contentsOf: activeDurations.map { $0 })
        tags.append(contentsOf: activeRatings.map { $0 })
        tags.append(contentsOf: activeDecades.map { $0 })
        return tags
    }

    // MARK: - Methods

    func clearAllFilters() {
        activeGenres.removeAll()
        activeLanguages.removeAll()
        activeMoods.removeAll()
        activeDurations.removeAll()
        activeRatings.removeAll()
        activeDecades.removeAll()
        fetchMovies()
    }

    func removeFilter(_ tag: String) {
        activeGenres.remove(tag)
        activeLanguages.remove(tag)
        activeMoods.remove(tag)
        activeDurations.remove(tag)
        activeRatings.remove(tag)
        activeDecades.remove(tag)
        fetchMovies()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchMovies()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            $activeGenres,
            $activeLanguages,
            $activeMoods,
            $activeDurations
        )
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.fetchMovies()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            $activeRatings,
            $activeDecades,
            $sortOption
        )
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.fetchMovies()
        }
        .store(in: &cancellables)
    }

    func fetchMovies() {
        isLoading = true
        currentPage = 0

        Task {
            do {
                let fetchedMovies = try await ExploreService.shared.searchMovies(
                    query: searchQuery.isEmpty ? nil : searchQuery,
                    genres: Array(activeGenres),
                    languages: Array(activeLanguages),
                    moods: Array(activeMoods),
                    durations: Array(activeDurations),
                    ratings: Array(activeRatings),
                    decades: Array(activeDecades),
                    sortOption: sortOption,
                    limit: pageSize,
                    offset: 0
                )

                await MainActor.run {
                    self.movies = fetchedMovies
                    self.totalResults = fetchedMovies.count
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("Error fetching movies: \(error)")
                #endif
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable, Identifiable {
    case ratingDesc = "rating_desc"
    case ratingAsc = "rating_asc"
    case durationDesc = "duration_desc"
    case durationAsc = "duration_asc"
    case yearDesc = "year_desc"
    case yearAsc = "year_asc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ratingDesc: return "Rating: High → Low"
        case .ratingAsc: return "Rating: Low → High"
        case .durationDesc: return "Duration: Longest first"
        case .durationAsc: return "Duration: Shortest first"
        case .yearDesc: return "Year: Newest first"
        case .yearAsc: return "Year: Oldest first"
        }
    }

    var category: String {
        if rawValue.contains("rating") { return "Rating" }
        if rawValue.contains("duration") { return "Duration" }
        return "Year"
    }

    var icon: String {
        switch self {
        case .ratingDesc, .ratingAsc: return "★"
        case .durationDesc, .durationAsc: return "⏱"
        case .yearDesc, .yearAsc: return "📅"
        }
    }
}
