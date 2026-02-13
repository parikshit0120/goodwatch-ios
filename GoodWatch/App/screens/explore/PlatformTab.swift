import SwiftUI

// ============================================
// PLATFORM TAB
// ============================================
// Circular 3D platform tiles + filtered movie grid
// Design matches PlatformSelectorView (Pick For Me OTT page)

struct PlatformTab: View {

    @StateObject private var viewModel = PlatformViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Platform grid — circular 3D tiles
            platformGrid

            // Selected platform info + sort
            if viewModel.selectedPlatform != nil {
                selectedPlatformRow
            }

            // Movie grid
            movieGrid
        }
    }

    // MARK: - Platform Grid (Circular 3D Design)

    private var platformGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(PlatformViewModel.platforms, id: \.name) { platform in
                ExplorePlatformTile(
                    platform: platform,
                    count: viewModel.platformCounts[platform.name] ?? 0,
                    isSelected: viewModel.selectedPlatform == platform.name,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.selectedPlatform == platform.name {
                                viewModel.selectedPlatform = nil
                            } else {
                                viewModel.selectedPlatform = platform.name
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Selected Platform Row

    private var selectedPlatformRow: some View {
        HStack {
            if let platform = viewModel.selectedPlatform {
                Text(platform)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GWColors.white)

                if let count = viewModel.platformCounts[platform], count > 0 {
                    Text("\(count) movies")
                        .font(.system(size: 13))
                        .foregroundColor(GWColors.lightGray)
                }
            }

            Spacer()

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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Movie Grid

    private var movieGrid: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.movies.isEmpty {
                loadingView
            } else if viewModel.selectedPlatform == nil {
                emptySelectionView
            } else if viewModel.movies.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(viewModel.movies, id: \.id) { movie in
                        MovieGridCard(movie: movie) {
                            viewModel.selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
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
            Text("Loading movies...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("Select a platform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text("Tap a platform above to browse its catalog")
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundColor(GWColors.gold.opacity(0.6))

            Text("No movies found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GWColors.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Circular 3D Platform Tile (matches PlatformSelectorView design)

struct ExplorePlatformTile: View {
    let platform: PlatformInfo
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    private let circleSize: CGFloat = 80

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Circular 3D container
                ZStack {
                    // 3D Circle with gradient background
                    Circle()
                        .fill(
                            isSelected
                                ? platform.gradient
                                : LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "2C2C2E"),
                                        Color(hex: "1C1C1E")
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            // Inner highlight for 3D effect
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(isSelected ? 0.15 : 0.1),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            // Selection border - golden outline
                            Circle()
                                .stroke(
                                    isSelected ? GWColors.gold.opacity(0.7) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .shadow(color: isSelected ? GWColors.gold.opacity(0.2) : Color.clear, radius: 12, x: 0, y: 0)

                    // Platform logo — fills the circle with small margin
                    Image(platform.logoAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                }

                // Platform name
                Text(platform.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? GWColors.gold : GWColors.white)
                    .lineLimit(1)

                // Movie count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? GWColors.gold.opacity(0.8) : GWColors.lightGray.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Platform Info

struct PlatformInfo {
    let name: String
    let logoAsset: String
    let gradient: LinearGradient

    static let netflix = PlatformInfo(
        name: "Netflix",
        logoAsset: "netflix_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "E50914"), Color(hex: "8B0710")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let primeVideo = PlatformInfo(
        name: "Prime Video",
        logoAsset: "prime_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "00A8E1"), Color(hex: "005F85")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let jioHotstar = PlatformInfo(
        name: "Jio Hotstar",
        logoAsset: "hotstar_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "1F80E0"), Color(hex: "0E4070")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let appleTVPlus = PlatformInfo(
        name: "Apple TV+",
        logoAsset: "appletv_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "a2a2a2"), Color(hex: "606060")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let zee5 = PlatformInfo(
        name: "ZEE5",
        logoAsset: "zee5_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "8230C6"), Color(hex: "4A1875")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let sonyLIV = PlatformInfo(
        name: "SonyLIV",
        logoAsset: "sonyliv_logo",
        gradient: LinearGradient(
            colors: [Color(hex: "555555"), Color(hex: "2A2A2A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
