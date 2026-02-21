import SwiftUI

// ============================================
// PROFILE TAB - User account & preferences
// ============================================
// Shows user info, watch stats, taste profile, and settings.
// Part of the Explore journey's bottom tab bar.

struct ProfileTab: View {
    @ObservedObject private var userService = UserService.shared
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var cachedTagWeights: [String: Double] = [:]

    var onSignOut: (() -> Void)?

    // Taste profile derived from cached tag weights
    private var tagWeights: [String: Double] {
        cachedTagWeights
    }

    private var archetype: UserArchetype? {
        guard !tagWeights.isEmpty else { return nil }

        // Only show archetype when we have enough meaningful data to be confident.
        // Require at least 10 tags that have deviated from the default weight of 1.0.
        // This means the user has had enough accept/reject interactions for the
        // archetype to actually reflect their taste — not just random noise.
        let learnedTagCount = tagWeights.values.filter { abs($0 - 1.0) > 0.001 }.count
        guard learnedTagCount >= 10 else { return nil }

        return UserArchetype.derive(from: tagWeights)
    }

    // Top genre/mood preferences from tag weights
    private var topPreferences: [(String, Double)] {
        tagWeights
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (formatTagName($0.key), $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar + Name
                profileHeader

                // Archetype card
                if let archetype = archetype {
                    archetypeSection(archetype)
                }

                // Stats
                statsSection

                // Taste Profile
                if !topPreferences.isEmpty {
                    tasteProfileSection
                }

                // Watchlist summary
                watchlistSummary

                // Account section
                accountSection

                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 16)
        }
        .background(GWColors.black)
        .onAppear {
            cachedTagWeights = TagWeightStore.shared.getWeights()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GWColors.gold.opacity(0.3), GWColors.gold.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                if let initial = userDisplayName.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(GWColors.gold)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(GWColors.gold)
                }
            }

            // Name / email
            Text(userDisplayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GWColors.white)

            if let email = userService.currentUser?.email, !email.isEmpty {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(GWColors.lightGray)
            }

            // Auth provider badge
            if let provider = userService.currentUser?.auth_provider, provider != "anonymous" {
                HStack(spacing: 4) {
                    Image(systemName: provider == "apple" ? "apple.logo" : "g.circle.fill")
                        .font(.system(size: 11))
                    Text("Signed in with \(provider.capitalized)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(GWColors.lightGray.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Archetype

    private func archetypeSection(_ archetype: UserArchetype) -> some View {
        VStack(spacing: 12) {
            sectionHeader("Your Watch Personality")

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(archetype.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(archetype.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(GWColors.white)

                        Text(archetype.description)
                            .font(.system(size: 12))
                            .foregroundColor(GWColors.lightGray)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(archetype.traits, id: \.self) { trait in
                        Text(trait)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GWColors.gold.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(GWColors.gold.opacity(0.12))
                            .cornerRadius(10)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(GWColors.darkGray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GWColors.gold.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Your Activity")

            HStack(spacing: 12) {
                statCard(
                    icon: "heart.fill",
                    value: "\(watchlist.count)",
                    label: "Watchlist",
                    color: Color(hex: "FF4D6A")
                )

                statCard(
                    icon: "eye.fill",
                    value: "\(interactionCount)",
                    label: "Movies Seen",
                    color: GWColors.gold
                )

                statCard(
                    icon: "hand.thumbsup.fill",
                    value: "\(acceptCount)",
                    label: "Picked",
                    color: Color(hex: "4CAF50")
                )
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(GWColors.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(GWColors.darkGray)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GWColors.surfaceBorder, lineWidth: 1)
        )
    }

    // MARK: - Taste Profile

    private var tasteProfileSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Your Taste Profile")

            VStack(spacing: 8) {
                ForEach(topPreferences, id: \.0) { tag, weight in
                    tasteBar(tag: tag, weight: weight)
                }
            }
            .padding(16)
            .background(GWColors.darkGray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
            )
        }
    }

    private func tasteBar(tag: String, weight: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GWColors.white)

                Spacer()

                // Show as percentage-like indicator
                Text(weightLabel(weight))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(weight > 1.0 ? GWColors.gold : GWColors.lightGray)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GWColors.surfaceBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            weight > 1.0
                                ? LinearGradient.goldGradient
                                : LinearGradient(colors: [GWColors.lightGray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * barFraction(weight), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Watchlist Summary

    private var watchlistSummary: some View {
        VStack(spacing: 12) {
            sectionHeader("Watchlist")

            if watchlist.count == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                        .foregroundColor(GWColors.lightGray.opacity(0.4))

                    Text("No movies saved yet. Tap the ♡ on any movie to start building your watchlist.")
                        .font(.system(size: 13))
                        .foregroundColor(GWColors.lightGray.opacity(0.6))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GWColors.darkGray)
                .cornerRadius(14)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "FF4D6A"))

                    Text("\(watchlist.count) movie\(watchlist.count == 1 ? "" : "s") saved")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GWColors.white)

                    Spacer()

                    Text("View in Watchlist tab")
                        .font(.system(size: 11))
                        .foregroundColor(GWColors.gold)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GWColors.darkGray)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GWColors.surfaceBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Account")

            VStack(spacing: 0) {
                // App version
                accountRow(icon: "info.circle", label: "App Version", value: appVersion)

                Divider().background(GWColors.surfaceBorder)

                // Sign out
                Button {
                    handleSignOut()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 24)

                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(GWColors.darkGray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GWColors.surfaceBorder, lineWidth: 1)
            )
        }
    }

    private func accountRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(GWColors.lightGray)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GWColors.white)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(GWColors.lightGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GWColors.lightGray.opacity(0.8))
            Spacer()
        }
    }

    // MARK: - Helpers

    private var userDisplayName: String {
        // 1. Check for cached display name (stored during Google/Apple sign-in)
        if let cachedName = UserDefaults.standard.string(forKey: "gw_user_display_name"), !cachedName.isEmpty {
            return cachedName
        }
        // 2. Derive from email (take part before @, capitalize)
        if let email = userService.currentUser?.email, !email.isEmpty {
            let localPart = email.components(separatedBy: "@").first ?? "User"
            // Clean up: "john.doe" → "John Doe", "johndoe123" → "Johndoe123"
            return localPart
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        return "GoodWatch User"
    }

    private var interactionCount: Int {
        // Approximate from onboarding step (proxy for interaction count)
        let step = GWKeychainManager.shared.getOnboardingStep()
        return max(0, step - 1)
    }

    private var acceptCount: Int {
        // Get from maturity info via stored weights count as proxy
        let weights = tagWeights
        // Each watch_now adds +0.15, so count positively-weighted tags
        return weights.values.filter { $0 > 1.0 }.count
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func formatTagName(_ tag: String) -> String {
        tag.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func weightLabel(_ weight: Double) -> String {
        if weight > 1.2 { return "Strong" }
        if weight > 1.0 { return "Positive" }
        if weight > 0.8 { return "Neutral" }
        return "Low"
    }

    private func barFraction(_ weight: Double) -> CGFloat {
        // Normalize weight to 0-1 range for bar display
        // Weights typically range from 0.5 to 2.0
        let normalized = (weight - 0.5) / 1.5 // maps 0.5-2.0 → 0-1
        return CGFloat(max(0.05, min(1.0, normalized)))
    }

    private func handleSignOut() {
        // Clear cached user data
        UserDefaults.standard.removeObject(forKey: "gw_user_id")
        UserDefaults.standard.removeObject(forKey: "gw_user_display_name")
        // Reset user service state
        UserService.shared.currentUser = nil
        UserService.shared.currentProfile = nil
        UserService.shared.isAuthenticated = false
        // Clear watchlist user scope
        WatchlistManager.shared.clearForSignOut()
        // Navigate back to landing
        onSignOut?()
    }
}
