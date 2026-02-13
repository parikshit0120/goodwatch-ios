import SwiftUI

// ============================================
// WATCHLIST TAB
// ============================================
// Shows saved movies from WatchlistManager
// Grid layout matching DiscoverTab style

struct WatchlistTab: View {

    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var movies: [Movie] = []
    @State private var isLoading: Bool = false
    @State private var selectedMovie: Movie?

    var body: some View {
        VStack(spacing: 0) {
            // Header count
            if !isLoading && !movies.isEmpty {
                HStack {
                    Text("\(movies.count) saved")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // Movie grid
            ScrollView {
                if isLoading {
                    loadingView
                } else if movies.isEmpty {
                    emptyView
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(movies, id: \.id) { movie in
                            MovieGridCard(movie: movie) {
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
        }
        .onAppear {
            fetchWatchlistMovies()
        }
        .onChange(of: watchlist.movieIds) { _ in
            fetchWatchlistMovies()
        }
    }

    private func fetchWatchlistMovies() {
        let ids = Array(watchlist.movieIds)
        guard !ids.isEmpty else {
            movies = []
            return
        }

        isLoading = true

        Task {
            do {
                let fetched = try await ExploreService.shared.fetchMoviesByIds(ids)
                await MainActor.run {
                    self.movies = fetched
                    self.isLoading = false
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

            Text("Tap the ♡ on any movie to save it here")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
