import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var allMovies: [Movie] = Movie.samples
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var showCelebration = false
    @State private var likedMovie: Movie?
    @State private var showMovieDetail = false
    @State private var selectedMovie: Movie?
    
    var availableMovies: [Movie] {
        viewModel.getDiscoveryMovies(allMovies: allMovies)
    }
    
    var currentMovie: Movie? {
        guard currentIndex < availableMovies.count else { return nil }
        return availableMovies[currentIndex]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GWColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Active Moods
                    if !viewModel.selectedMoods.isEmpty {
                        activeMoodsChips
                    }
                    
                    Spacer()
                    
                    // Card Stack or Empty State
                    if availableMovies.isEmpty || currentIndex >= availableMovies.count {
                        emptyState
                    } else {
                        cardStack
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    if currentMovie != nil {
                        actionButtons
                            .padding(.bottom, 100)
                    }
                }
            }
            .sheet(isPresented: $showCelebration) {
                if let movie = likedMovie {
                    CelebrationView(movie: movie)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showMovieDetail) {
                if let movie = selectedMovie {
                    NavigationStack {
                        MovieDetailView(movie: movie)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle().fill(GWColors.accent).frame(width: 6, height: 6)
                    Circle().fill(GWColors.accent).frame(width: 6, height: 6)
                    Circle().fill(GWColors.accent).frame(width: 6, height: 6)
                }
                Text("Discover")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Reset button
            if currentIndex > 0 || !viewModel.excludedMovies.isEmpty {
                Button(action: resetDiscovery) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(GWColors.textSecondary)
                }
            }
            
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    // MARK: - Active Moods Chips
    private var activeMoodsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.selectedMoods), id: \.self) { mood in
                    HStack(spacing: 4) {
                        Text(mood)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Button(action: { viewModel.toggleMood(mood) }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GWColors.accentSecondary.opacity(0.5)))
                }
                
                Button(action: { viewModel.clearMoods() }) {
                    Text("Clear all")
                        .font(.caption)
                        .foregroundColor(GWColors.accent)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Card Stack
    private var cardStack: some View {
        ZStack {
            ForEach(Array(availableMovies.enumerated().reversed()), id: \.element.id) { index, movie in
                if index >= currentIndex && index < currentIndex + 3 {
                    MovieSwipeCard(
                        movie: movie,
                        isTop: index == currentIndex,
                        offset: index == currentIndex ? offset : .zero
                    )
                    .scaleEffect(index == currentIndex ? 1 : 1 - CGFloat(index - currentIndex) * 0.05)
                    .offset(y: CGFloat(index - currentIndex) * 10)
                    .zIndex(Double(availableMovies.count - index))
                    .gesture(
                        index == currentIndex ?
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { gesture in
                                handleSwipe(gesture.translation)
                            }
                        : nil
                    )
                    .onTapGesture {
                        if index == currentIndex {
                            selectedMovie = movie
                            showMovieDetail = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(GWColors.textSecondary)
            
            Text("You've seen all movies!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Reset to discover again or check your watchlist")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: resetDiscovery) {
                Text("Reset Discovery")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(GWColors.accentSecondary)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 24) {
            // Skip
            Button(action: skipMovie) {
                ZStack {
                    Circle()
                        .fill(GWColors.cardBackground)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            // Add to Watchlist (without liking)
            Button(action: addToWatchlistOnly) {
                ZStack {
                    Circle()
                        .fill(GWColors.accent)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "bookmark.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            // Like (adds to watchlist + shows celebration)
            Button(action: likeMovie) {
                ZStack {
                    Circle()
                        .fill(GWColors.accentSecondary.opacity(0.3))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(GWColors.accentSecondary)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func handleSwipe(_ translation: CGSize) {
        if translation.width > 100 {
            likeMovie()
        } else if translation.width < -100 {
            skipMovie()
        } else {
            withAnimation(.spring()) {
                offset = .zero
            }
        }
    }
    
    private func skipMovie() {
        guard let movie = currentMovie else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: -500, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.skipMovie(movie)
            currentIndex += 1
            offset = .zero
        }
    }
    
    private func likeMovie() {
        guard let movie = currentMovie else { return }
        
        likedMovie = movie
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: 500, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.likeMovie(movie)
            showCelebration = true
            currentIndex += 1
            offset = .zero
        }
    }
    
    private func addToWatchlistOnly() {
        guard let movie = currentMovie else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: 0, height: -300)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.addToWatchlist(movie)
            currentIndex += 1
            offset = .zero
        }
    }
    
    private func resetDiscovery() {
        currentIndex = 0
    }
}

// MARK: - Movie Swipe Card
struct MovieSwipeCard: View {
    let movie: Movie
    let isTop: Bool
    let offset: CGSize
    
    var rotation: Double {
        Double(offset.width / 20)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Poster
            AsyncImage(url: URL(string: movie.backdropURL ?? movie.posterURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 24)
                    .fill(GWColors.cardBackground)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
            .frame(width: UIScreen.main.bounds.width - 40, height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Gradient
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Tap hint
            if isTop && offset == .zero {
                VStack {
                    HStack {
                        Spacer()
                        Text("Tap for details")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                    Spacer()
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack {
                    Text(movie.year)
                    Text("•")
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", movie.rating))
                    }
                }
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                
                // AI Says
                if let insight = movie.aiInsight {
                    HStack(alignment: .top, spacing: 8) {
                        Text("AI Says:")
                            .fontWeight(.semibold)
                            .foregroundColor(GWColors.accentSecondary)
                        
                        Text(insight)
                            .foregroundColor(GWColors.textSecondary)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // LIKE/NOPE indicators
            if isTop {
                HStack {
                    // NOPE
                    Text("NOPE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 3)
                        )
                        .rotationEffect(.degrees(-20))
                        .opacity(offset.width < -50 ? min(Double(-offset.width - 50) / 100, 1) : 0)
                    
                    Spacer()
                    
                    // LIKE
                    Text("LIKE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 3)
                        )
                        .rotationEffect(.degrees(20))
                        .opacity(offset.width > 50 ? min(Double(offset.width - 50) / 100, 1) : 0)
                }
                .padding(30)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Celebration View
struct CelebrationView: View {
    let movie: Movie
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            GWColors.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Checkmark
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GWColors.accentSecondary)
                    Text("Great Choice!")
                        .foregroundColor(GWColors.accentSecondary)
                }
                .font(.title2)
                .fontWeight(.semibold)
                
                // Poster
                AsyncImage(url: URL(string: movie.posterURL)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(GWColors.cardBackground)
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Movie Info
                VStack(spacing: 8) {
                    Text(movie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(movie.year)
                        Text("•")
                        Text(movie.runtime)
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", movie.rating))
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(GWColors.textSecondary)
                }
                
                // Where to Watch
                VStack(spacing: 12) {
                    Text("Where to Watch")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        ForEach(movie.streamingPlatforms.prefix(3), id: \.self) { platform in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(GWColors.cardBackground)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(String(platform.prefix(1)))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                Button("Open") {}
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(GWColors.accentSecondary)
                                )
                            }
                        }
                    }
                }
                .padding(.top)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Added to Watchlist")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                    
                    GWButton(title: "Share", style: .outline) {}
                    
                    Button("Find Similar") {}
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(.horizontal)
                
                Button("Back to Discovery") {
                    dismiss()
                }
                .foregroundColor(GWColors.accentSecondary)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    DiscoverView()
        .environmentObject(GoodWatchViewModel())
}
