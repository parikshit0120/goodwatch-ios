import SwiftUI

// MARK: - Search View
struct SearchView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @Environment(\.dismiss) private var dismiss
    
    let filters = ["All", "Genre", "Year", "Director", "OTT Platform"]
    let recentSearches = RecentSearch.samples
    let trendingSearches = Movie.samples.prefix(6)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(GWColors.textSecondary)
                        
                        TextField("Search movies, actors, lists...", text: $searchText)
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(GWColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GWColors.cardBackground)
                    )
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(GWColors.accent)
                }
                .padding()
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            FilterPill(
                                title: filter,
                                isSelected: selectedFilter == filter
                            )
                            .onTapGesture {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Trending Searches
                        if searchText.isEmpty {
                            trendingSection
                            recentSearchesSection
                        } else {
                            searchResults
                        }
                    }
                    .padding(.top)
                }
            }
            .background(GWColors.background.ignoresSafeArea())
        }
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trending Searches")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(trendingSearches)) { movie in
                    VStack(alignment: .leading, spacing: 4) {
                        AsyncImage(url: URL(string: movie.posterURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 140)
                                .clipped()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(GWColors.cardBackground)
                                .frame(height: 140)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(movie.title)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(movie.year)
                            .font(.caption2)
                            .foregroundColor(GWColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Searches")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(recentSearches) { search in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(GWColors.textSecondary)
                        
                        Text(search.query)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "xmark")
                                .foregroundColor(GWColors.textSecondary)
                        }
                    }
                    .padding()
                    
                    Divider()
                        .background(GWColors.divider)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Search Results
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results for \"\(searchText)\"")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(Movie.samples.filter { $0.title.localizedCaseInsensitiveContains(searchText) }) { movie in
                NavigationLink(destination: MovieDetailView(movie: movie).environmentObject(viewModel)) {
                    HStack(spacing: 12) {
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
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var viewModel: GoodWatchViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = true
    @State private var autoPlayEnabled = false
    @State private var selectedLanguage = "English"
    @State private var selectedContentLanguages = ["English", "Hindi"]
    @State private var showSignOutAlert = false
    
    var body: some View {
        List {
            // Preferences Section
            Section {
                NavigationLink(destination: Text("Language")) {
                    SettingsRow(icon: "globe", title: "Language", value: selectedLanguage)
                }
                
                NavigationLink(destination: Text("Content Languages")) {
                    SettingsRow(icon: "checkmark.circle", title: "Content Languages", value: "English, Hindi +1")
                }
                
                NavigationLink(destination: Text("Streaming Platforms")) {
                    SettingsRow(icon: "play.tv", title: "Streaming Platforms", value: "Netflix, Prime +1")
                }
                
                Toggle(isOn: $notificationsEnabled) {
                    SettingsRow(icon: "bell", title: "Notifications", value: nil)
                }
                .tint(GWColors.accentSecondary)
            } header: {
                Text("Preferences")
                    .foregroundColor(GWColors.accentSecondary)
            }
            .listRowBackground(GWColors.cardBackground)
            
            // Account Section
            Section {
                NavigationLink(destination: Text("Edit Profile")) {
                    SettingsRow(icon: "person", title: "Edit profile", subtitle: "Manage your personal details and preferences")
                }
                
                NavigationLink(destination: Text("Subscription")) {
                    SettingsRow(icon: "creditcard", title: "Manage subscription", subtitle: "View or change your plan")
                }
                
                NavigationLink(destination: Text("Linked Accounts")) {
                    SettingsRow(icon: "link", title: "Linked accounts", subtitle: "Connect social media or other services")
                }
            } header: {
                Text("Account")
                    .foregroundColor(GWColors.accentSecondary)
            }
            .listRowBackground(GWColors.cardBackground)
            
            // About Section
            Section {
                NavigationLink(destination: Text("Rate")) {
                    SettingsRow(icon: "star", title: "Rate GoodWatch", value: nil)
                }
                
                NavigationLink(destination: Text("Share")) {
                    SettingsRow(icon: "square.and.arrow.up", title: "Share with friends", value: nil)
                }
                
                NavigationLink(destination: Text("Help")) {
                    SettingsRow(icon: "questionmark.circle", title: "Help & FAQ", value: nil)
                }
                
                NavigationLink(destination: Text("Privacy")) {
                    SettingsRow(icon: "lock", title: "Privacy Policy", value: nil)
                }
                
                NavigationLink(destination: Text("Terms")) {
                    SettingsRow(icon: "doc.text", title: "Terms of Service", value: nil)
                }
            } header: {
                Text("About")
                    .foregroundColor(GWColors.accentSecondary)
            }
            .listRowBackground(GWColors.cardBackground)
            
            // Data Section
            Section {
                Button(action: {}) {
                    SettingsRow(icon: "arrow.counterclockwise", title: "Clear watch history", subtitle: "Delete all your watched movies history")
                }
                
                Button(action: {}) {
                    SettingsRow(icon: "arrow.down.doc", title: "Export my data", subtitle: "Download a copy of your account data")
                }
            } header: {
                Text("Data")
                    .foregroundColor(GWColors.accentSecondary)
            }
            .listRowBackground(GWColors.cardBackground)
            
            // Sign Out
            Section {
                Button(action: { showSignOutAlert = true }) {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(GWColors.accent)
                        Spacer()
                    }
                }
            }
            .listRowBackground(GWColors.cardBackground)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    viewModel.resetAllData()
                    hasCompletedOnboarding = false
                }
            } message: {
                Text("This will clear all your data and return to onboarding.")
            }
            
            // Version
            Section {
                HStack {
                    Spacer()
                    Text("App Version 1.0.0 (Build 123)")
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(GWColors.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(GWColors.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(GWColors.textSecondary)
            }
        }
    }
}

#Preview {
    SearchView()
}
