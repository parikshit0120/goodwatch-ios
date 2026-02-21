import SwiftUI
import Combine

// ============================================
// NEW RELEASES VIEW MODEL
// ============================================

@MainActor
class NewReleasesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var movies: [Movie] = []
    @Published var isLoading: Bool = false
    @Published var selectedPlatform: String?
    @Published var selectedContentType: String?
    @Published var selectedMovie: Movie?
    @Published var showSortMenu: Bool = false
    @Published var sortOption: SortOption = .yearDesc
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

    // MARK: - Options

    static let platforms = [
        "Netflix", "Prime Video", "Jio Hotstar",
        "Apple TV+", "ZEE5", "SonyLIV"
    ]

    static let contentTypes = ["Movies", "Series", "Documentary"]

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
        // Server-side filters: platform, contentType, sort trigger a re-fetch
        Publishers.CombineLatest3($selectedPlatform, $sortOption, $selectedContentType)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.fetchMovies()
            }
            .store(in: &cancellables)

        // Client-side filters: apply locally without re-fetch
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
                let fetchedMovies = try await ExploreService.shared.fetchNewReleases(
                    platform: selectedPlatform,
                    contentType: selectedContentType,
                    sortOption: sortOption,
                    limit: 50
                )

                await MainActor.run {
                    self.unfilteredMovies = fetchedMovies
                    self.applyClientFilters()
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("Error fetching new releases: \(error)")
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
                let counts = try await ExploreService.shared.fetchNewReleaseCounts()
                await MainActor.run {
                    self.platformCounts = counts
                    self.totalCount = counts.values.reduce(0, +)
                }
            } catch {
                #if DEBUG
                print("Error fetching platform counts: \(error)")
                #endif
            }
        }
    }
}
