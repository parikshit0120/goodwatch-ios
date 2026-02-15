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

    // genres comes from Supabase as a JSON string, not a native array
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tmdb_id = try container.decode(Int.self, forKey: .tmdb_id)
        title = try container.decode(String.self, forKey: .title)
        content_type = try container.decode(String.self, forKey: .content_type)
        section = try container.decode(String.self, forKey: .section)
        release_date = try container.decodeIfPresent(String.self, forKey: .release_date)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        poster_path = try container.decodeIfPresent(String.self, forKey: .poster_path)
        backdrop_path = try container.decodeIfPresent(String.self, forKey: .backdrop_path)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        vote_average = try container.decodeIfPresent(Double.self, forKey: .vote_average)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        original_language = try container.decode(String.self, forKey: .original_language)

        // Try decoding as [GenreItem] first, then as JSON string
        if let genreArray = try? container.decodeIfPresent([GenreItem].self, forKey: .genres) {
            genres = genreArray
        } else if let genreString = try? container.decodeIfPresent(String.self, forKey: .genres),
                  let data = genreString.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([GenreItem].self, from: data) {
            genres = parsed
        } else {
            genres = nil
        }
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
    }

    // MARK: - Published Properties

    @Published var items: [UpcomingRelease] = []
    @Published var isLoading: Bool = false
    @Published var selectedSection: Section = .theatrical
    @Published var selectedPlatform: String?
    @Published var selectedContentType: String?
    @Published var selectedGenre: String?
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

    static let genres = [
        "Action", "Comedy", "Drama", "Horror", "Romance",
        "Thriller", "Science Fiction", "Animation", "Crime", "Documentary"
    ]

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
        Publishers.CombineLatest4($selectedSection, $selectedPlatform, $selectedContentType, $selectedGenre)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
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
                var fetched = try await ExploreService.shared.fetchUpcomingReleases(
                    section: selectedSection.rawValue,
                    platform: selectedPlatform,
                    contentType: selectedContentType,
                    limit: 200
                )

                // Client-side genre filter
                if let genre = selectedGenre {
                    fetched = fetched.filter { item in
                        guard let genres = item.genreNames else { return false }
                        return genres.contains(genre)
                    }
                }

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
