import SwiftUI

struct ListsHubView: View {
    @State private var searchText = ""
    @State private var selectedPlatform: String?
    
    let platforms = StreamingPlatform.all
    let staffPicks = CuratedList.samples
    let moodCategories = MoodCategory.samples
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Featured Section
                    featuredSection
                    
                    // By Platform
                    platformSection
                    
                    // Staff Picks
                    staffPicksSection
                    
                    // By Mood
                    moodSection
                    
                    Spacer(minLength: 100)
                }
            }
            .background(GWColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Curated Lists")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(staffPicks.filter { $0.isFeatured }) { list in
                        NavigationLink(destination: ListDetailView(list: list)) {
                            FeaturedListCard(list: list)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Platform Section
    private var platformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Platform")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(platforms) { platform in
                        FilterPill(
                            title: platform.name,
                            isSelected: selectedPlatform == platform.name,
                            icon: "play.tv"
                        )
                        .onTapGesture {
                            selectedPlatform = selectedPlatform == platform.name ? nil : platform.name
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Staff Picks Section
    private var staffPicksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Staff Picks")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(staffPicks) { list in
                    NavigationLink(destination: ListDetailView(list: list)) {
                        StaffPickRow(list: list)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Mood Section
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Mood")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(moodCategories) { category in
                    MoodCategoryCard(category: category)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Featured List Card
struct FeaturedListCard: View {
    let list: CuratedList
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: list.imageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 280, height: 160)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(GWColors.cardBackground)
                    .frame(width: 280, height: 160)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    if let tag = list.tag {
                        Text(tag)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(GWColors.accentSecondary)
                            )
                    }
                    
                    Text("\(list.movieCount) films")
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                }
            }
            .padding()
        }
        .frame(width: 280, height: 160)
    }
}

// MARK: - Staff Pick Row
struct StaffPickRow: View {
    let list: CuratedList
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: list.imageURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GWColors.cardBackground)
            }
            .frame(width: 80, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(list.movieCount) films • Updated \(list.updatedAt)")
                    .font(.caption)
                    .foregroundColor(GWColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(GWColors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GWColors.cardBackground)
        )
    }
}

// MARK: - Mood Category Card
struct MoodCategoryCard: View {
    let category: MoodCategory
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: category.imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: 140)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(GWColors.cardBackground)
                        .frame(width: geometry.size.width, height: 140)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(category.subtitle)
                        .font(.caption2)
                        .foregroundColor(GWColors.textSecondary)
                        .lineLimit(2)
                }
                .padding(12)
            }
        }
        .frame(height: 140)
    }
}

// MARK: - List Detail View
struct ListDetailView: View {
    let list: CuratedList
    let movies = Movie.samples
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: list.imageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 200)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(GWColors.cardBackground)
                                .frame(width: geometry.size.width, height: 200)
                        }
                        
                        LinearGradient(
                            colors: [.clear, GWColors.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .frame(height: 200)
                
                // Title and Description
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Updated \(list.updatedAt) • Curated by GoodWatch")
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                    
                    Text("Dive into the scariest tales streaming on Netflix. This curated list features bone-chilling selections of horror masterpieces.")
                        .font(.subheadline)
                        .foregroundColor(GWColors.textSecondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                
                // Numbered Movie List
                VStack(spacing: 0) {
                    ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                        NumberedMovieRow(rank: index + 1, movie: movie)
                        
                        if index < movies.count - 1 {
                            Divider()
                                .background(GWColors.divider)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Shuffle Play Button
                Button(action: {}) {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Shuffle Play")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Capsule().fill(GWColors.accentSecondary)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
        }
        .background(GWColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Numbered Movie Row
struct NumberedMovieRow: View {
    let rank: Int
    let movie: Movie
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(GWColors.accentSecondary)
                .frame(width: 30)
            
            AsyncImage(url: URL(string: movie.posterURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GWColors.cardBackground)
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                HStack {
                    Text(movie.year)
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", movie.rating))
                    }
                }
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
                
                if let insight = movie.aiInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ListsHubView()
}
