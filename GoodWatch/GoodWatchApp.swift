import SwiftUI

@main
struct GoodWatchApp: App {
    @StateObject private var viewModel = GoodWatchViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(viewModel)
            } else {
                OnboardingView()
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .environmentObject(viewModel)
                    .tag(0)
                
                DiscoverView()
                    .environmentObject(viewModel)
                    .tag(1)
                
                WatchlistView()
                    .environmentObject(viewModel)
                    .tag(2)
                
                ListsHubView()
                    .tag(3)
                
                ProfileView()
                    .environmentObject(viewModel)
                    .tag(4)
            }
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("safari.fill", "Discover"),
        ("bookmark.fill", "Watchlist"),
        ("square.grid.2x2.fill", "Lists"),
        ("person.fill", "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 20))
                        
                        Text(tabs[index].label)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == index ? GWColors.accentSecondary : GWColors.textSecondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(GWColors.background)
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }
}

#Preview {
    MainTabView()
}
