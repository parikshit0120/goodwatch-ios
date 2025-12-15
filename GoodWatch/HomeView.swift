import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var showStoryViewer = false
    @State private var selectedStory: Story?
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var navigateToDiscover = false
    
    let stories = Story.samples
    let moods = Mood.all
    let trendingMovies = Movie.samples
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tonight's Pick
                    TonightsPickCard(movie: Movie.sample)
                        .padding(.horizontal)
                    
                    // Stories Section
                    storiesSection
                    
                    // Mood Selection
                    moodSection
                    
                    // Trending Movies
                    movieSection(title: "Trending Movies", movies: Array(trendingMovies.prefix(4)))
                    
                    // New Releases
                    movieSection(title: "New Releases", movies: Array(trendingMovies.suffix(4)))
                    
                    // Personal Picks
                    personalPicksSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .background(GWColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    GoodWatchLogo(size: 24)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showStoryViewer) {
                if let story = selectedStory {
                    StoryViewerView(story: story)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
                    .environmentObject(viewModel)
            }
            .navigationDestination(isPresented: $navigateToDiscover) {
                DiscoverView()
                    .environmentObject(viewModel)
            }
        }
    }
    
    // MARK: - Stories Section
    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stories for You")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stories) { story in
                        StoryCircle(
                            title: story.title,
                            imageName: story.imageURL,
                            isNew: story.isNew
                        )
                        .onTapGesture {
                            selectedStory = story
                            showStoryViewer = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Mood Section
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("What's your mood?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !viewModel.selectedMoods.isEmpty {
                    Button(action: {
                        navigateToDiscover = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Find Movies")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(GWColors.accent)
                    }
                }
            }
            .padding(.horizontal)
            
            // 3x4 Grid of moods
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(moods) { mood in
                    MoodChip(
                        title: mood.name,
                        isSelected: viewModel.selectedMoods.contains(mood.name)
                    ) {
                        viewModel.toggleMood(mood.name)
                    }
                }
            }
            .padding(.horizontal)
            
            // Selected moods count
            if !viewModel.selectedMoods.isEmpty {
                HStack {
                    Text("\(viewModel.selectedMoods.count) mood\(viewModel.selectedMoods.count > 1 ? "s" : "") selected")
                        .font(.caption)
                        .foregroundColor(GWColors.accentSecondary)
                    
                    Spacer()
                    
                    Button(action: { viewModel.clearMoods() }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(GWColors.textSecondary)
                    }
                }
                .padding(.horizontal)
            }
            
            // Shuffle Button
            Button(action: {
                viewModel.shuffleMoods(from: moods)
            }) {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Can't decide? Shuffle for me")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("Shuffle")
                        .font(.subheadline)
                        .foregroundColor(GWColors.accentSecondary)
                }
                .foregroundColor(GWColors.textSecondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GWColors.cardBackground)
                )
            }
            .padding(.horizontal)
            
            // Start Discovery Button (when moods selected)
            if !viewModel.selectedMoods.isEmpty {
                Button(action: {
                    navigateToDiscover = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Discovery")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GWColors.accent)
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Movie Section
    private func movieSection(title: String, movies: [Movie]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, showSeeAll: true)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(movies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie).environmentObject(viewModel)) {
                            MoviePosterCard(
                                title: movie.title,
                                year: movie.year,
                                posterURL: movie.posterURL
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Personal Picks Section
    private var personalPicksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Picks", showSeeAll: true)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(trendingMovies.prefix(6)) { movie in
                    NavigationLink(destination: MovieDetailView(movie: movie).environmentObject(viewModel)) {
                        VStack(alignment: .leading, spacing: 6) {
                            AsyncImage(url: URL(string: movie.posterURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(GWColors.cardBackground)
                                    .frame(height: 200)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text(movie.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(movie.year)
                                .font(.caption2)
                                .foregroundColor(GWColors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Story Viewer
struct StoryViewerView: View {
    let story: Story
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var progress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Story Image
            AsyncImage(url: URL(string: story.imageURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(hex: "1A1625")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            // Gradient overlay
            VStack {
                Spacer()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 400)
            }
            .ignoresSafeArea()
            
            // Content
            VStack {
                // Progress bar
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(GWColors.accentSecondary)
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 3)
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                // Close and mute buttons
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // Movie Info
                VStack(spacing: 16) {
                    if let movie = story.movie {
                        Text(movie.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text(movie.year)
                            Text("•")
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                Text(String(format: "%.1f", movie.rating))
                            }
                        }
                        .foregroundColor(GWColors.textSecondary)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            GWButton(title: "Watch Now", style: .secondary) {}
                            
                            GWButton(title: "Add to List", style: .outline) {
                                viewModel.addToWatchlist(movie)
                                dismiss()
                            }
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Text(story.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(GoodWatchViewModel())
}
