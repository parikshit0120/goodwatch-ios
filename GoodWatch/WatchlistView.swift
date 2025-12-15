import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var selectedFilter = "To Watch"
    @State private var sortOption = "Recently Added"
    @State private var showMovieDetail = false
    @State private var selectedMovie: Movie?
    
    let filters = ["To Watch", "Watched"]
    let sortOptions = ["Recently Added", "Title A-Z", "Rating", "Year"]
    
    var filteredWatchlist: [WatchlistItem] {
        let items = selectedFilter == "To Watch" ? viewModel.toWatchList : viewModel.watchedList
        
        switch sortOption {
        case "Title A-Z":
            return items.sorted { $0.movie.title < $1.movie.title }
        case "Rating":
            return items.sorted { $0.movie.rating > $1.movie.rating }
        case "Year":
            return items.sorted { $0.movie.year > $1.movie.year }
        default: // Recently Added
            return items.sorted { $0.addedAt > $1.addedAt }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GWColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Filter Tabs
                    filterTabs
                    
                    // Sort Row
                    sortRow
                    
                    // Movie Grid
                    if filteredWatchlist.isEmpty {
                        emptyState
                    } else {
                        movieGrid
                    }
                }
            }
            .sheet(isPresented: $showMovieDetail) {
                if let movie = selectedMovie {
                    MovieDetailView(movie: movie)
                        .environmentObject(viewModel)
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("Watchlist")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Watchlist")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(viewModel.watchlist.count) films")
                    .font(.subheadline)
                    .foregroundColor(GWColors.accentSecondary)
            }
            
            HStack(spacing: 0) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter 
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(filter)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedFilter == filter ? .white : GWColors.textSecondary)
                            
                            // Count badge
                            Text("\(filter == "To Watch" ? viewModel.toWatchList.count : viewModel.watchedList.count)")
                                .font(.caption2)
                                .foregroundColor(selectedFilter == filter ? .white.opacity(0.8) : GWColors.textSecondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedFilter == filter ?
                            GWColors.accentSecondary : Color.clear
                        )
                    }
                }
            }
            .background(GWColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Sort Row
    private var sortRow: some View {
        HStack {
            Spacer()
            
            Menu {
                ForEach(sortOptions, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort: \(sortOption)")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(GWColors.textSecondary)
            }
        }
        .padding()
    }
    
    // MARK: - Movie Grid
    private var movieGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredWatchlist) { item in
                    watchlistCard(item)
                        .onTapGesture {
                            selectedMovie = item.movie
                            showMovieDetail = true
                        }
                        .contextMenu {
                            contextMenuItems(for: item)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuItems(for item: WatchlistItem) -> some View {
        if item.isWatched {
            Button(action: { viewModel.markAsUnwatched(item.movie) }) {
                Label("Mark as Unwatched", systemImage: "eye.slash")
            }
        } else {
            Button(action: { viewModel.markAsWatched(item.movie) }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
        }
        
        Divider()
        
        Button(role: .destructive, action: { viewModel.removeFromWatchlist(item.movie) }) {
            Label("Remove from Watchlist", systemImage: "trash")
        }
    }
    
    // MARK: - Watchlist Card
    private func watchlistCard(_ item: WatchlistItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.movie.posterURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GWColors.cardBackground)
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(GWColors.textSecondary)
                        )
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Watched indicator
                if item.isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white).padding(2))
                        .padding(8)
                }
                
                // Rating badge
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.movie.rating))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        
                        Spacer()
                    }
                    .padding(8)
                }
            }
            
            Text(item.movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
            
            HStack {
                Text(item.movie.year)
                    .font(.caption2)
                    .foregroundColor(GWColors.textSecondary)
                
                Spacer()
                
                // Quick action button
                Button(action: {
                    if item.isWatched {
                        viewModel.markAsUnwatched(item.movie)
                    } else {
                        viewModel.markAsWatched(item.movie)
                    }
                }) {
                    Image(systemName: item.isWatched ? "eye.fill" : "eye")
                        .font(.caption)
                        .foregroundColor(item.isWatched ? GWColors.accentSecondary : GWColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: selectedFilter == "To Watch" ? "bookmark" : "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(GWColors.textSecondary)
            
            Text(selectedFilter == "To Watch" ? "No movies to watch" : "No watched movies yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(selectedFilter == "To Watch" 
                 ? "Start discovering movies to build your watchlist" 
                 : "Mark movies as watched to track your progress")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .multilineTextAlignment(.center)
            
            if selectedFilter == "To Watch" {
                NavigationLink(destination: DiscoverView().environmentObject(viewModel)) {
                    Text("Start Discovering")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(GWColors.accentSecondary)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    WatchlistView()
        .environmentObject(GoodWatchViewModel())
}
