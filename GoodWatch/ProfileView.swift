import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    let tasteProfile = TasteProfile.samples
    
    var recentActivity: [UserActivity] {
        // Generate from actual watchlist
        viewModel.watchlist.prefix(3).map { item in
            UserActivity(
                movie: item.movie,
                action: item.isWatched ? "Watched" : "Added to Watchlist",
                timeAgo: formatTimeAgo(item.addedAt)
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User Card
                    userCard
                    
                    // Streak Card
                    streakCard
                    
                    // Your Stats
                    statsSection
                    
                    // Taste Profile
                    tasteProfileSection
                    
                    // Achievements
                    achievementsSection
                    
                    // Your Lists
                    yourListsSection
                    
                    // Recent Activity
                    if !recentActivity.isEmpty {
                        recentActivitySection
                    }
                    
                    // Share Stats Button
                    GWButton(title: "Share My Stats", style: .primary) {}
                        .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .background(GWColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView().environmentObject(viewModel)) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
    
    // MARK: - User Card
    private var userCard: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(GWColors.accentSecondary)
                    .frame(width: 80, height: 80)
                
                Text("PJ")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Parikshit")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Member since 2024")
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GWColors.cardBackground)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundColor(GWColors.streakOrange)
            
            Text("\(viewModel.userStats.dayStreak)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("day streak")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
            
            Text("Best streak: \(viewModel.userStats.bestStreak) days")
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GWColors.cardBackground)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(value: "\(viewModel.userStats.moviesDiscovered)", label: "Movies Discovered", icon: "film")
                StatBox(value: "\(viewModel.userStats.calculatedPickRate)%", label: "Pick Rate", icon: "chart.line.uptrend.xyaxis")
                StatBox(value: "\(viewModel.watchlist.count)", label: "In Watchlist", icon: "bookmark")
                StatBox(value: "\(viewModel.userStats.totalSwipes)", label: "Total Swipes", icon: "hand.draw")
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Taste Profile Section
    private var tasteProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Taste Profile")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(tasteProfile, id: \.genre) { profile in
                    TasteProfileBar(genre: profile.genre, percentage: profile.percentage)
                }
                
                if let topMood = viewModel.selectedMoods.first {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(GWColors.accentSecondary)
                        
                        Text("Most selected mood")
                            .foregroundColor(GWColors.textSecondary)
                        
                        Spacer()
                        
                        Text(topMood)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GWColors.cardBackground)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    AchievementBadge(
                        title: "First Watch",
                        isUnlocked: viewModel.watchedList.count >= 1,
                        icon: "play.fill"
                    )
                    AchievementBadge(
                        title: "Movie Marathon",
                        isUnlocked: viewModel.watchedList.count >= 5,
                        icon: "trophy.fill"
                    )
                    AchievementBadge(
                        title: "Curator",
                        isUnlocked: viewModel.watchlist.count >= 10,
                        icon: "star.fill"
                    )
                    AchievementBadge(
                        title: "Explorer",
                        isUnlocked: viewModel.userStats.totalSwipes >= 50,
                        icon: "safari"
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Your Lists Section
    private var yourListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Lists")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {}
                    .font(.subheadline)
                    .foregroundColor(GWColors.accentSecondary)
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                ListRow(title: "To Watch", count: viewModel.toWatchList.count)
                ListRow(title: "Watched", count: viewModel.watchedList.count)
                ListRow(title: "Liked", count: viewModel.likedMovies.count)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GWColors.cardBackground)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(recentActivity) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GWColors.cardBackground)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(GWColors.accentSecondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GWColors.cardBackground)
        )
    }
}

// MARK: - List Row
struct ListRow: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(GWColors.accentSecondary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(count) movies")
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: UserActivity
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: activity.movie.posterURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GWColors.cardBackground)
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.movie.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(activity.action) \(activity.timeAgo)")
                    .font(.caption)
                    .foregroundColor(GWColors.textSecondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(GoodWatchViewModel())
}
