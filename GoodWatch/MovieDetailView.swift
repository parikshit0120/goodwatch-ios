import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var isInWatchlist: Bool {
        viewModel.isInWatchlist(movie)
    }
    
    var isLiked: Bool {
        viewModel.likedMovies.contains { $0.id == movie.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                heroSection
                
                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Title Section
                    titleSection
                    
                    // Action Buttons
                    actionButtons
                    
                    // Genre Tags
                    genreTags
                    
                    // AI Insight
                    aiInsightSection
                    
                    // Synopsis
                    synopsisSection
                    
                    // Cast & Crew
                    castSection
                    
                    // Where to Watch
                    whereToWatchSection
                    
                    // Similar Movies
                    similarMoviesSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .background(GWColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GWColors.textSecondary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: {
                        if isLiked {
                            // Can't unlike for now
                        } else {
                            viewModel.likeMovie(movie)
                        }
                    }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? GWColors.accent : .white)
                    }
                }
                .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: movie.backdropURL ?? movie.posterURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: 400)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(GWColors.cardBackground)
                        .frame(width: geometry.size.width, height: 400)
                }
                
                LinearGradient(
                    colors: [.clear, GWColors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
        }
        .frame(height: 400)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(movie.title) (\(movie.year))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Text(movie.year)
                Text("•")
                Text(movie.runtime)
            }
            .font(.subheadline)
            .foregroundColor(GWColors.textSecondary)
            
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", movie.rating))
                    .foregroundColor(.yellow)
                Text("(TMDB)")
                    .foregroundColor(GWColors.textSecondary)
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.addToWatchlist(movie)
                    viewModel.markAsWatched(movie)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Pick This")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(GWColors.accentSecondary)
                    )
                }
                
                Button(action: {
                    if isInWatchlist {
                        viewModel.removeFromWatchlist(movie)
                    } else {
                        viewModel.addToWatchlist(movie)
                    }
                }) {
                    HStack {
                        Image(systemName: isInWatchlist ? "checkmark" : "plus")
                        Text(isInWatchlist ? "Added" : "Add")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(isInWatchlist ? GWColors.accentSecondary.opacity(0.3) : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(isInWatchlist ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: { dismiss() }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(GWColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Genre Tags
    private var genreTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(movie.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(GWColors.cardBackground)
                        )
                }
            }
        }
    }
    
    // MARK: - AI Insight Section
    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(GWColors.accentSecondary)
                Text("AI Insight")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .font(.subheadline)
            
            Text(movie.aiInsight ?? "An epic tale of destiny and power, this film delivers stunning visuals and a deep narrative, perfect for fans of grand-scale storytelling and complex world-building.")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GWColors.cardBackground)
        )
    }
    
    // MARK: - Synopsis Section
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(movie.overview ?? "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family. Facing a choice between the love of his life and the fate of the known universe.")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .lineSpacing(4)
            
            // Cast info
            if !movie.cast.isEmpty {
                Text("Cast: \(movie.cast.map { $0.name }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(GWColors.accentSecondary)
            }
        }
    }
    
    // MARK: - Cast Section
    private var castSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast & Crew")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(CastMember.samples) { member in
                        VStack(spacing: 6) {
                            AsyncImage(url: URL(string: member.photoURL)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(GWColors.cardBackground)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            Text(member.name.components(separatedBy: " ").first ?? "")
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                    }
                }
            }
        }
    }
    
    // MARK: - Where to Watch Section
    private var whereToWatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where to Watch")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(movie.streamingPlatforms.prefix(4), id: \.self) { platform in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(GWColors.cardBackground)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(platform.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                        
                        Button("Open") {}
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(GWColors.accentSecondary)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Similar Movies Section
    private var similarMoviesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Similar Movies")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Movie.samples.filter { $0.id != movie.id }.prefix(4)) { similarMovie in
                        NavigationLink(destination: MovieDetailView(movie: similarMovie).environmentObject(viewModel)) {
                            VStack(alignment: .leading, spacing: 4) {
                                AsyncImage(url: URL(string: similarMovie.posterURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(GWColors.cardBackground)
                                }
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("\(similarMovie.title) (\(similarMovie.year))")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: Movie.sample)
            .environmentObject(GoodWatchViewModel())
    }
}
