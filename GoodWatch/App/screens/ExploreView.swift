import SwiftUI

// ============================================
// EXPLORE VIEW - Main Container
// ============================================
// 6-tab interface with BOTTOM tab bar: Discover, New Releases, By Platform, Rent, Watchlist, Profile
// Auth is handled BEFORE entering this view (via ExploreAuthView)
// Home button in header to switch back to Pick For Me journey

struct ExploreView: View {

    enum Tab: String, CaseIterable {
        // Short labels for bottom tab bar (must fit in 7 columns)
        case discover = "Discover"
        case newReleases = "New"
        case upcoming = "Soon"
        case byPlatform = "Platform"
        case rent = "Rent"
        case watchlist = "Saved"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .discover: return "magnifyingglass"
            case .newReleases: return "sparkles"
            case .upcoming: return "calendar.badge.clock"
            case .byPlatform: return "square.grid.2x2"
            case .rent: return "tag"
            case .watchlist: return "heart.fill"
            case .profile: return "person.fill"
            }
        }

        /// Full title shown in the header bar
        var headerTitle: String {
            switch self {
            case .discover: return "Discover"
            case .newReleases: return "New Releases"
            case .upcoming: return "Upcoming"
            case .byPlatform: return "By Platform"
            case .rent: return "Rent"
            case .watchlist: return "Watchlist"
            case .profile: return "Profile"
            }
        }
    }

    @State private var selectedTab: Tab = .discover
    @ObservedObject private var watchlist = WatchlistManager.shared

    let onClose: () -> Void
    var onHome: (() -> Void)?

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            // Full explore experience (auth is handled before entering this view)
            VStack(spacing: 0) {
                // Header
                header

                // Tab content
                tabContent

                // Bottom tab bar
                bottomTabBar
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            AppLogo(size: 20)

            Text(selectedTab.headerTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.goldGradient)

            Spacer()

            // Home button — always present to switch back to Pick For Me
            if let home = onHome {
                Button(action: home) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(GWColors.lightGray)
                        .padding(8)
                        .background(GWColors.darkGray)
                        .cornerRadius(GWRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: GWRadius.sm)
                                .stroke(GWColors.surfaceBorder, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))

                            // Watchlist badge count
                            if tab == .watchlist && watchlist.count > 0 {
                                Text("\(watchlist.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(GWColors.black)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(GWColors.gold)
                                    .cornerRadius(6)
                                    .offset(x: 10, y: -7)
                            }
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(selectedTab == tab ? GWColors.gold : GWColors.lightGray.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .background(
            Rectangle()
                .fill(GWColors.darkGray)
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
        )
    }

    // MARK: - Tab Content
    // Lazy tab rendering: only the active tab + previously visited tabs stay alive.
    // This prevents 6 ViewModels from all fetching data simultaneously on entry.
    @State private var visitedTabs: Set<Tab> = [.discover]

    private var tabContent: some View {
        ZStack {
            if visitedTabs.contains(.discover) {
                DiscoverTab()
                    .opacity(selectedTab == .discover ? 1 : 0)
                    .allowsHitTesting(selectedTab == .discover)
            }

            if visitedTabs.contains(.newReleases) {
                NewReleasesTab()
                    .opacity(selectedTab == .newReleases ? 1 : 0)
                    .allowsHitTesting(selectedTab == .newReleases)
            }

            if visitedTabs.contains(.upcoming) {
                UpcomingReleasesTab()
                    .opacity(selectedTab == .upcoming ? 1 : 0)
                    .allowsHitTesting(selectedTab == .upcoming)
            }

            if visitedTabs.contains(.byPlatform) {
                PlatformTab()
                    .opacity(selectedTab == .byPlatform ? 1 : 0)
                    .allowsHitTesting(selectedTab == .byPlatform)
            }

            if visitedTabs.contains(.rent) {
                RentTab()
                    .opacity(selectedTab == .rent ? 1 : 0)
                    .allowsHitTesting(selectedTab == .rent)
            }

            if visitedTabs.contains(.watchlist) {
                WatchlistTab()
                    .opacity(selectedTab == .watchlist ? 1 : 0)
                    .allowsHitTesting(selectedTab == .watchlist)
            }

            if visitedTabs.contains(.profile) {
                ProfileTab(onSignOut: onHome)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
        }
        .onChange(of: selectedTab) { newTab in
            visitedTabs.insert(newTab)
        }
    }

}

// MARK: - Preview

#if DEBUG
struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView(onClose: {})
    }
}
#endif
