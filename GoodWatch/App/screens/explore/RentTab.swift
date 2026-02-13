import SwiftUI

// ============================================
// RENT TAB
// ============================================
// List-style view of movies available to rent or buy
// across Apple TV, Google Play, YouTube, Amazon Video

struct RentTab: View {

    @StateObject private var viewModel = RentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Platform filter tabs
            platformFilterTabs

            // Sort dropdown
            sortRow

            // Movie list
            movieList
        }
    }

    // MARK: - Header Description

    private var headerDescription: some View {
        Text("Available to Rent or Buy")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(GWColors.lightGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    // MARK: - Platform Filter Tabs

    private var platformFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PlatformFilterButton(
                    title: "All",
                    count: viewModel.totalCount,
                    isSelected: viewModel.selectedPlatform == nil,
                    action: { viewModel.selectedPlatform = nil }
                )

                ForEach(RentViewModel.platforms, id: \.self) { platform in
                    PlatformFilterButton(
                        title: platform,
                        count: viewModel.platformCounts[platform] ?? 0,
                        isSelected: viewModel.selectedPlatform == platform,
                        action: { viewModel.selectedPlatform = platform }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Sort Row

    private var sortRow: some View {
        HStack {
            Button {
                viewModel.showSortMenu.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text(viewModel.sortOption.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(GWColors.lightGray)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(GWColors.darkGray)
                .cornerRadius(GWRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.full)
                        .stroke(GWColors.surfaceBorder, lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Movie List

    private var movieList: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.movies.isEmpty {
                loadingView
            } else if viewModel.movies.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.movies, id: \.id) { movie in
                        MovieListCard(movie: movie, showRentalProviders: true) {
                            viewModel.selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $viewModel.selectedMovie) { movie in
            MovieDetailSheet(movie: movie)
        }
        .sheet(isPresented: $viewModel.showSortMenu) {
            SortMenuSheet(selectedSort: $viewModel.sortOption)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GWColors.gold)
                .scaleEffect(1.2)
            Text("Loading rentals...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No rentals available")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Rental data is being synced — check back soon")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
