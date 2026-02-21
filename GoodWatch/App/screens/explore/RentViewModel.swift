import SwiftUI
import Combine

// ============================================
// RENT VIEW MODEL
// ============================================
// Manages state for the Rent/Buy tab showing
// movies available to rent or buy on Apple TV,
// Google Play, YouTube, Amazon Video

@MainActor
class RentViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var movies: [Movie] = []
    @Published var isLoading: Bool = false
    @Published var selectedPlatform: String?
    @Published var selectedMovie: Movie?
    @Published var showSortMenu: Bool = false
    @Published var sortOption: SortOption = .ratingDesc
    @Published var platformCounts: [String: Int] = [:]
    @Published var totalCount: Int = 0

    // Filters (client-side on fetched results)
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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<Void, Never>?
    private var unfilteredMovies: [Movie] = []

    // MARK: - Platform Options

    static let platforms = [
        "Apple TV", "Google Play Movies", "YouTube", "Amazon Video"
    ]

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        !activeGenres.isEmpty || !activeLanguages.isEmpty ||
        !activeMoods.isEmpty || !activeDurations.isEmpty ||
        !activeRatings.isEmpty || !activeDecades.isEmpty
    }

    var activeFilterTags: [String] {
        var tags: [String] = []
        tags.append(contentsOf: activeGenres)
        tags.append(contentsOf: activeLanguages)
        tags.append(contentsOf: activeMoods)
        tags.append(contentsOf: activeDurations)
        tags.append(contentsOf: activeRatings)
        tags.append(contentsOf: activeDecades)
        return tags
    }

    // MARK: - Initialization

    init() {
        setupPublishers()
        fetchMovies()
        fetchPlatformCounts()
    }

    // MARK: - Methods

    func clearAllFilters() {
        activeGenres.removeAll()
        activeLanguages.removeAll()
        activeMoods.removeAll()
        activeDurations.removeAll()
        activeRatings.removeAll()
        activeDecades.removeAll()
        applyClientFilters()
    }

    func removeFilter(_ tag: String) {
        activeGenres.remove(tag)
        activeLanguages.remove(tag)
        activeMoods.remove(tag)
        activeDurations.remove(tag)
        activeRatings.remove(tag)
        activeDecades.remove(tag)
        applyClientFilters()
    }

    private func setupPublishers() {
        // Server-side: platform + sort trigger re-fetch
        Publishers.CombineLatest($selectedPlatform, $sortOption)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.fetchMovies()
            }
            .store(in: &cancellables)

        // Client-side filters: apply locally
        let filterStream = Publishers.CombineLatest4(
            $activeGenres, $activeLanguages, $activeMoods, $activeDurations
        ).map { _ in () }

        let secondaryStream = Publishers.CombineLatest(
            $activeRatings, $activeDecades
        ).map { _ in () }

        Publishers.Merge(filterStream, secondaryStream)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.applyClientFilters()
            }
            .store(in: &cancellables)
    }

    func fetchMovies() {
        currentFetchTask?.cancel()
        isLoading = true

        currentFetchTask = Task {
            do {
                let fetchedMovies = try await ExploreService.shared.fetchRentals(
                    platform: selectedPlatform,
                    sortOption: sortOption,
                    limit: 100
                )

                await MainActor.run {
                    self.unfilteredMovies = fetchedMovies
                    self.applyClientFilters()
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("Error fetching rental movies: \(error)")
                #endif
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func applyClientFilters() {
        movies = ClientMovieFilter.apply(
            to: unfilteredMovies,
            genres: activeGenres,
            languages: activeLanguages,
            moods: activeMoods,
            durations: activeDurations,
            ratings: activeRatings,
            decades: activeDecades
        )
    }

    private func fetchPlatformCounts() {
        Task {
            do {
                let counts = try await ExploreService.shared.fetchRentalPlatformCounts()
                let total = try await ExploreService.shared.fetchTotalRentalCount()

                await MainActor.run {
                    self.platformCounts = counts
                    self.totalCount = total
                }
            } catch {
                #if DEBUG
                print("Error fetching rental platform counts: \(error)")
                #endif
            }
        }
    }
}
