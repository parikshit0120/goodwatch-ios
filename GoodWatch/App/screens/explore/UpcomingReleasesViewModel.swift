import SwiftUI
import Combine

// ============================================
// UPCOMING RELEASES VIEW MODEL
// ============================================
// Fetches from upcoming_releases Supabase table.
// Cross-references movies table to get ratings for OTT items.

// MARK: - UpcomingRelease Model

struct UpcomingRelease: Codable, Identifiable {
    let id: String
    let tmdb_id: Int
    let title: String
    let content_type: String
    let section: String
    let release_date: String?
    let platform: String?
    let poster_path: String?
    let backdrop_path: String?
    let overview: String?
    let vote_average: Double?
    let popularity: Double?
    let genres: [GenreItem]?
    let original_language: String

    var genreNames: [String]? {
        genres?.compactMap { $0.name }
    }

    struct GenreItem: Codable {
        let name: String?
    }
}

// MARK: - ViewModel

@MainActor
class UpcomingReleasesViewModel: ObservableObject {

    // MARK: - Section Enum

    enum Section: String, CaseIterable {
        case theatrical = "theatrical"
        case ott = "ott"

        var displayName: String {
            switch self {
            case .theatrical: return "In Theatres"
            case .ott: return "On OTTs"
            }
        }

        var icon: String {
            switch self {
            case .theatrical: return "ticket"
            case .ott: return "tv"
            }
        }
    }

    // MARK: - Published Properties

    @Published var items: [UpcomingRelease] = []
    @Published var isLoading: Bool = false
    @Published var selectedSection: Section = .theatrical
    @Published var selectedPlatform: String?
    @Published var selectedContentType: String?
    @Published var selectedMovie: Movie?
    @Published var sectionCounts: [Section: Int] = [:]
    @Published var platformCounts: [String: Int] = [:]
    @Published var enrichedMovies: [Int: Movie] = [:] // tmdb_id → Movie

    // MARK: - Options

    static let ottPlatforms = [
        "Netflix", "Amazon Prime Video", "JioHotstar",
        "Apple TV+", "ZEE5", "SonyLIV"
    ]

    static let contentTypes = ["Movies", "Series"]

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        setupPublishers()
        fetchItems()
        fetchSectionCounts()
    }

    // MARK: - Publishers

    private func setupPublishers() {
        Publishers.CombineLatest3($selectedSection, $selectedPlatform, $selectedContentType)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.fetchItems()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Items

    func fetchItems() {
        currentFetchTask?.cancel()
        isLoading = true

        currentFetchTask = Task {
            do {
                let fetched = try await ExploreService.shared.fetchUpcomingReleases(
                    section: selectedSection.rawValue,
                    platform: selectedPlatform,
                    contentType: selectedContentType,
                    limit: 100
                )

                // For OTT items, cross-reference movies table for ratings
                let tmdbIds = fetched.map { $0.tmdb_id }
                var enriched: [Int: Movie] = [:]

                if !tmdbIds.isEmpty {
                    let movies = try await ExploreService.shared.fetchMoviesByTmdbIds(tmdbIds)
                    for movie in movies {
                        if let tmdbId = movie.tmdb_id {
                            enriched[tmdbId] = movie
                        }
                    }
                }

                await MainActor.run {
                    self.items = fetched
                    self.enrichedMovies = enriched
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("Error fetching upcoming releases: \(error)")
                #endif
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Section Counts

    private func fetchSectionCounts() {
        Task {
            do {
                let counts = try await ExploreService.shared.fetchUpcomingSectionCounts()
                await MainActor.run {
                    self.sectionCounts = [
                        .theatrical: counts["theatrical"] ?? 0,
                        .ott: counts["ott"] ?? 0
                    ]
                }

                // Also fetch OTT platform breakdown
                let platCounts = try await ExploreService.shared.fetchUpcomingPlatformCounts()
                await MainActor.run {
                    self.platformCounts = platCounts
                }
            } catch {
                #if DEBUG
                print("Error fetching upcoming counts: \(error)")
                #endif
            }
        }
    }
}
