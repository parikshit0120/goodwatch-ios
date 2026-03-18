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
    @Published var selectedMovie: Movie?
    @Published var sectionCounts: [Section: Int] = [:]
    @Published var platformCounts: [String: Int] = [:]
    @Published var enrichedMovies: [Int: Movie] = [:] // tmdb_id -> Movie

    // Multi-select filters (client-side on fetched results)
    @Published var activeGenres: Set<String> = []
    @Published var activeLanguages: Set<String> = []
    @Published var activeMoods: Set<String> = []
    @Published var activeDurations: Set<String> = []
    @Published var activeRatings: Set<String> = []
    @Published var activeDecades: Set<String> = []

    // Sort
    @Published var sortOption: SortOption = .yearDesc

    // Sheet states
    @Published var showGenreFilter: Bool = false
    @Published var showLanguageFilter: Bool = false
    @Published var showMoodFilter: Bool = false
    @Published var showDurationFilter: Bool = false
    @Published var showRatingFilter: Bool = false
    @Published var showDecadeFilter: Bool = false
    @Published var showSortMenu: Bool = false

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

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<Void, Never>?
    private var unfilteredItems: [UpcomingRelease] = []

    private static let languageToISO: [String: String] = [
        "english": "en", "hindi": "hi", "japanese": "ja",
        "tamil": "ta", "telugu": "te", "malayalam": "ml",
        "spanish": "es", "korean": "ko", "kannada": "kn",
        "bengali": "bn", "marathi": "mr", "french": "fr",
        "chinese": "zh", "portuguese": "pt", "punjabi": "pa",
        "gujarati": "gu"
    ]

    // MARK: - Init

    init() {
        setupPublishers()
        fetchItems()
        fetchSectionCounts()
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

    // MARK: - Publishers

    private func setupPublishers() {
        // Server-side triggers: section, platform, contentType
        Publishers.CombineLatest3($selectedSection, $selectedPlatform, $selectedContentType)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.fetchItems()
            }
            .store(in: &cancellables)

        // Client-side filters
        let filterStream = Publishers.CombineLatest4(
            $activeGenres, $activeLanguages, $activeMoods, $activeDurations
        ).map { _ in () }

        let secondaryStream = Publishers.CombineLatest3(
            $activeRatings, $activeDecades, $sortOption
        ).map { _ in () }

        Publishers.Merge(filterStream, secondaryStream)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.applyClientFilters()
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
                    limit: 200
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
                    self.unfilteredItems = fetched
                    self.enrichedMovies = enriched
                    self.applyClientFilters()
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

    private func applyClientFilters() {
        var filtered = unfilteredItems

        // Genre filter (multi-select)
        if !activeGenres.isEmpty {
            filtered = filtered.filter { item in
                guard let genres = item.genreNames else { return false }
                return !activeGenres.isDisjoint(with: Set(genres))
            }
        }

        // Language filter (multi-select)
        if !activeLanguages.isEmpty {
            let isoCodes = Set(activeLanguages.compactMap { Self.languageToISO[$0.lowercased()] })
            filtered = filtered.filter { item in
                isoCodes.contains(item.original_language.lowercased())
            }
        }

        // Mood filter (genre-based, same logic as ClientMovieFilter)
        if !activeMoods.isEmpty {
            filtered = filtered.filter { item in
                guard let genres = item.genreNames else { return false }
                let genreSet = Set(genres.map { $0.lowercased() })
                return ClientMovieFilter.matchesMoodForGenres(genreSet: genreSet, moods: activeMoods)
            }
        }

        // Rating filter (use enriched movie GoodScore if available)
        if !activeRatings.isEmpty {
            filtered = filtered.filter { item in
                let score: Double
                if let movie = enrichedMovies[item.tmdb_id], let gs = movie.goodScoreDisplay {
                    score = Double(gs) / 10.0
                } else if let va = item.vote_average, va > 0 {
                    score = va
                } else {
                    return false
                }
                for rating in activeRatings {
                    switch rating {
                    case "6+": if score >= 6.0 { return true }
                    case "7+": if score >= 7.0 { return true }
                    case "8+": if score >= 8.0 { return true }
                    default: break
                    }
                }
                return false
            }
        }

        // Decade filter (use release_date year)
        if !activeDecades.isEmpty {
            filtered = filtered.filter { item in
                guard let dateStr = item.release_date,
                      let yearStr = dateStr.split(separator: "-").first,
                      let year = Int(yearStr) else { return false }
                for decade in activeDecades {
                    switch decade {
                    case "2020s": if year >= 2020 && year <= 2029 { return true }
                    case "2010s": if year >= 2010 && year <= 2019 { return true }
                    case "2000s": if year >= 2000 && year <= 2009 { return true }
                    case "90s": if year >= 1990 && year <= 1999 { return true }
                    // "80s" and "Classic" removed — pre-1990 excluded
                    default: break
                    }
                }
                return false
            }
        }

        // Duration filter (use enriched movie runtime if available)
        if !activeDurations.isEmpty {
            filtered = filtered.filter { item in
                guard let movie = enrichedMovies[item.tmdb_id] else { return true }
                let runtime = movie.runtimeMinutes
                if runtime <= 0 { return true }
                for duration in activeDurations {
                    switch duration {
                    case "Under 90 min": if runtime < 90 { return true }
                    case "90-150 min", "90\u{2013}150 min": if runtime >= 90 && runtime <= 150 { return true }
                    case "150+ min": if runtime >= 150 { return true }
                    case "Epic 180+": if runtime >= 180 { return true }
                    default: break
                    }
                }
                return false
            }
        }

        // Sort (apply on filtered results)
        switch sortOption {
        case .ratingDesc:
            filtered.sort { a, b in
                let scoreA = enrichedMovies[a.tmdb_id]?.rating ?? a.vote_average ?? 0
                let scoreB = enrichedMovies[b.tmdb_id]?.rating ?? b.vote_average ?? 0
                return scoreA > scoreB
            }
        case .ratingAsc:
            filtered.sort { a, b in
                let scoreA = enrichedMovies[a.tmdb_id]?.rating ?? a.vote_average ?? 0
                let scoreB = enrichedMovies[b.tmdb_id]?.rating ?? b.vote_average ?? 0
                return scoreA < scoreB
            }
        case .yearDesc:
            filtered.sort { ($0.release_date ?? "") > ($1.release_date ?? "") }
        case .yearAsc:
            filtered.sort { ($0.release_date ?? "") < ($1.release_date ?? "") }
        case .durationDesc:
            filtered.sort { a, b in
                let rtA = enrichedMovies[a.tmdb_id]?.runtimeMinutes ?? 0
                let rtB = enrichedMovies[b.tmdb_id]?.runtimeMinutes ?? 0
                return rtA > rtB
            }
        case .durationAsc:
            filtered.sort { a, b in
                let rtA = enrichedMovies[a.tmdb_id]?.runtimeMinutes ?? 0
                let rtB = enrichedMovies[b.tmdb_id]?.runtimeMinutes ?? 0
                return rtA < rtB
            }
        }

        items = filtered
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
