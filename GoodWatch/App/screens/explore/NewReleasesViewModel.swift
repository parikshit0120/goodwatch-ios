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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Options

    static let platforms = [
        "Netflix", "Prime Video", "Jio Hotstar",
        "Apple TV+", "ZEE5", "SonyLIV"
    ]

    static let contentTypes = ["Movies", "Series", "Documentary"]

    // MARK: - Initialization

    init() {
        setupPublishers()
        fetchMovies()
        fetchPlatformCounts()
    }

    // MARK: - Methods

    private func setupPublishers() {
        Publishers.CombineLatest3($selectedPlatform, $sortOption, $selectedContentType)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.fetchMovies()
            }
            .store(in: &cancellables)
    }

    func fetchMovies() {
        isLoading = true

        Task {
            do {
                let fetchedMovies = try await ExploreService.shared.fetchNewReleases(
                    platform: selectedPlatform,
                    contentType: selectedContentType,
                    sortOption: sortOption,
                    limit: 50
                )

                await MainActor.run {
                    self.movies = fetchedMovies
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
