import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        ZStack {
            GWColors.background.ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        hasCompletedOnboarding = true
                    }
                    .foregroundColor(GWColors.textSecondary)
                    .padding()
                }
                
                // Pages
                TabView(selection: $currentPage) {
                    OnboardingPage1(currentPage: $currentPage)
                        .tag(0)
                    
                    OnboardingPage2(currentPage: $currentPage)
                        .environmentObject(viewModel)
                        .tag(1)
                    
                    OnboardingPage3()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? GWColors.accentSecondary : GWColors.textSecondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Onboarding Page 1
struct OnboardingPage1: View {
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Movie thumbnails
            HStack(spacing: 12) {
                ForEach(Movie.samples.prefix(2)) { movie in
                    AsyncImage(url: URL(string: movie.posterURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GWColors.cardBackground)
                    }
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Icon
            Image(systemName: "film")
                .font(.system(size: 40))
                .foregroundColor(GWColors.accentSecondary)
                .padding(.top, 20)
            
            // Title
            Text("Welcome to\nGoodWatch")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Discover a universe of films tailored just for you. Track, rate, and share your cinematic journey.")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Tagline
            Text("Films worth your time.")
                .font(.headline)
                .foregroundColor(GWColors.accentSecondary)
            
            Spacer()
            
            // Next Button
            GWButton(title: "Get Started", style: .primary) {
                withAnimation {
                    currentPage = 1
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding(.top, 40)
    }
}

// MARK: - Onboarding Page 2 (Mood Selection)
struct OnboardingPage2: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @Binding var currentPage: Int
    @State private var selectedMoods: Set<String> = []
    
    let moods = ["Chill", "Intense", "Feel-Good", "Dark", "Romantic", "Mind-Bending", "Laugh", "Cry", "Thrill", "Think", "Adventure", "Inspire"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Image
            AsyncImage(url: URL(string: Movie.samples[3].posterURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GWColors.cardBackground)
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [GWColors.accent, GWColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            
            // Title
            Text("What moves you?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Pick at least 3")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
            
            // Mood Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(moods, id: \.self) { mood in
                    MoodChip(
                        title: mood,
                        isSelected: selectedMoods.contains(mood)
                    ) {
                        if selectedMoods.contains(mood) {
                            selectedMoods.remove(mood)
                        } else {
                            selectedMoods.insert(mood)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Selection count
            if selectedMoods.count > 0 && selectedMoods.count < 3 {
                Text("Select \(3 - selectedMoods.count) more")
                    .font(.caption)
                    .foregroundColor(GWColors.accent)
            }
            
            Spacer()
            
            // Navigation Buttons
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        currentPage = 0
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(GWColors.cardBackground)
                        )
                }
                
                Button(action: {
                    // Save moods to ViewModel
                    viewModel.setMoods(selectedMoods)
                    withAnimation {
                        currentPage = 2
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMoods.count >= 3 ? GWColors.accentSecondary : GWColors.cardBackground)
                        )
                }
                .disabled(selectedMoods.count < 3)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding Page 3
struct OnboardingPage3: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Popcorn Illustration
            ZStack {
                Circle()
                    .fill(GWColors.cardBackground)
                    .frame(width: 200, height: 200)
                
                VStack(spacing: 0) {
                    // Popcorn box with film reels
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GWColors.accent)
                            .frame(width: 100, height: 120)
                        
                        VStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.yellow)
                                    .frame(width: 30, height: 30)
                                Circle()
                                    .fill(.yellow)
                                    .frame(width: 25, height: 25)
                            }
                            .offset(y: -20)
                            
                            Spacer()
                        }
                        .frame(height: 120)
                    }
                }
            }
            
            // Title
            Text("Your Cinematic Journey\nAwaits")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Discover, track, and share your favorite films and series. Dive into a world of curated content tailored just for you.")
                .font(.subheadline)
                .foregroundColor(GWColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Get Started Button
            GWButton(title: "Let's Go!", style: .primary) {
                hasCompletedOnboarding = true
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(GoodWatchViewModel())
}
