import SwiftUI
import Combine

// ============================================
// PLATFORM VIEW MODEL
// ============================================

@MainActor
class PlatformViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var movies: [Movie] = []
    @Published var isLoading: Bool = false
    @Published var selectedPlatform: String?
    @Published var selectedMovie: Movie?
    @Published var showSortMenu: Bool = false
    @Published var sortOption: SortOption = .ratingDesc
    @Published var platformCounts: [String: Int] = [:]

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Platform Options

    static let platforms = [
        PlatformInfo.netflix,
        PlatformInfo.primeVideo,
        PlatformInfo.jioHotstar,
        PlatformInfo.appleTVPlus,
        PlatformInfo.zee5,
        PlatformInfo.sonyLIV
    ]

    // MARK: - Initialization

    init() {
        setupPublishers()
        fetchPlatformCounts()
    }

    // MARK: - Methods

    private func setupPublishers() {
        Publishers.CombineLatest($selectedPlatform, $sortOption)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] platform, _ in
                if platform != nil {
                    self?.fetchMovies()
                }
            }
            .store(in: &cancellables)
    }

    func fetchMovies() {
        guard let platform = selectedPlatform else {
            movies = []
            return
        }

        isLoading = true

        Task {
            do {
                let fetchedMovies = try await ExploreService.shared.fetchMoviesByPlatform(
                    platform: platform,
                    sortOption: sortOption,
                    limit: 100
                )

                await MainActor.run {
                    self.movies = fetchedMovies
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("Error fetching platform movies: \(error)")
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
                let counts = try await ExploreService.shared.fetchPlatformCounts()
                await MainActor.run {
                    self.platformCounts = counts
                }
            } catch {
                #if DEBUG
                print("Error fetching platform counts: \(error)")
                #endif
            }
        }
    }
}
