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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Platform Options

    static let platforms = [
        "Apple TV", "Google Play Movies", "YouTube", "Amazon Video"
    ]

    // MARK: - Initialization

    init() {
        setupPublishers()
        fetchMovies()
        fetchPlatformCounts()
    }

    // MARK: - Methods

    private func setupPublishers() {
        Publishers.CombineLatest($selectedPlatform, $sortOption)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.fetchMovies()
            }
            .store(in: &cancellables)
    }

    func fetchMovies() {
        isLoading = true

        Task {
            do {
                let fetchedMovies = try await ExploreService.shared.fetchRentals(
                    platform: selectedPlatform,
                    sortOption: sortOption,
                    limit: 100
                )

                await MainActor.run {
                    self.movies = fetchedMovies
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
