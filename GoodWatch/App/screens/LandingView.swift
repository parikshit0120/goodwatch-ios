import SwiftUI

// Screen 0: Landing View
// Simple: Logo + Wordmark + Tagline
// After 5+ uses: shows user profile archetype card
struct LandingView: View {
    let onContinue: () -> Void
    var onProfileTap: (() -> Void)?

    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var profileOpacity: Double = 0

    /// Derive user archetype from tag weights
    private var userArchetype: UserArchetype? {
        let weights = TagWeightStore.shared.getWeights()
        guard !weights.isEmpty else { return nil }

        // Check if user has enough interactions (stored in onboarding step as proxy)
        let step = GWKeychainManager.shared.getOnboardingStep()
        guard step >= 5 else { return nil }

        return UserArchetype.derive(from: weights)
    }

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                // Logo (Golden film strip) - 30% smaller
                AppLogo(size: 112)
                    .opacity(logoOpacity)

                Spacer().frame(height: 24)

                // Wordmark - 20% larger
                Text("GoodWatch")
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(LinearGradient.goldGradient)
                    .opacity(textOpacity)

                Spacer().frame(height: 12)

                // Tagline
                VStack(spacing: 4) {
                    Text("Stop browsing.")
                    Text("Start watching.")
                }
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.lightGray)
                .opacity(textOpacity)

                // User Profile Card (after 5+ uses)
                if let archetype = userArchetype {
                    Button {
                        onProfileTap?()
                    } label: {
                        UserProfileCard(archetype: archetype)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 40)
                    .opacity(profileOpacity)
                }

                Spacer()

                // CTA button
                Button(action: onContinue) {
                    Text("Pick for me")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.goldGradient)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 80)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1
            }
            // Profile card fades in slightly after text
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                profileOpacity = 1
            }
        }
    }
}

// MARK: - User Archetype

struct UserArchetype {
    let name: String        // e.g. "The Comfort Seeker"
    let emoji: String       // e.g. "🎬"
    let description: String // e.g. "You lean toward feel-good, easy watches"
    let traits: [String]    // e.g. ["Feel-good", "Light", "Safe picks"]

    static func derive(from weights: [String: Double]) -> UserArchetype {
        // Find dominant emotional outcome
        let emotionalOutcomes: [(String, String)] = [
            ("feel_good", "feel-good"), ("uplifting", "uplifting"),
            ("dark", "dark"), ("disturbing", "intense"), ("bittersweet", "bittersweet")
        ]
        let energyLevels: [(String, String)] = [
            ("calm", "calm"), ("tense", "gripping"), ("high_energy", "high-energy")
        ]
        let cogLevels: [(String, String)] = [
            ("light", "easy"), ("medium", "balanced"), ("heavy", "deep")
        ]
        let riskLevels: [(String, String)] = [
            ("safe_bet", "safe picks"), ("polarizing", "varied picks"), ("acquired_taste", "adventurous")
        ]

        func topWeight(_ pairs: [(String, String)]) -> (String, String, Double) {
            var best = pairs[0]
            var bestW = weights[pairs[0].0] ?? 1.0
            for pair in pairs {
                let w = weights[pair.0] ?? 1.0
                if w > bestW {
                    best = pair
                    bestW = w
                }
            }
            return (best.0, best.1, bestW)
        }

        let (emotionKey, emotionLabel, _) = topWeight(emotionalOutcomes)
        let (_, energyLabel, _) = topWeight(energyLevels)
        let (_, cogLabel, _) = topWeight(cogLevels)
        let (riskKey, riskLabel, _) = topWeight(riskLevels)

        // Determine archetype name
        let name: String
        let emoji: String
        switch emotionKey {
        case "feel_good", "uplifting":
            if riskKey == "safe_bet" {
                name = "The Comfort Seeker"
                emoji = "☀️"
            } else {
                name = "The Optimist"
                emoji = "🌈"
            }
        case "dark", "disturbing":
            name = "The Deep Diver"
            emoji = "🌊"
        case "bittersweet":
            name = "The Film Buff"
            emoji = "🎬"
        default:
            name = "The Explorer"
            emoji = "🧭"
        }

        let desc = "You lean toward \(emotionLabel), \(cogLabel) watches"
        let traits = [emotionLabel.capitalized, energyLabel.capitalized, riskLabel.capitalized]

        return UserArchetype(name: name, emoji: emoji, description: desc, traits: traits)
    }
}

// MARK: - User Profile Card

struct UserProfileCard: View {
    let archetype: UserArchetype

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(archetype.emoji)
                    .font(.system(size: 20))

                Text(archetype.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GWColors.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GWColors.lightGray.opacity(0.6))
            }

            Text(archetype.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(GWColors.lightGray.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(archetype.traits, id: \.self) { trait in
                    Text(trait)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GWColors.gold.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GWColors.gold.opacity(0.12))
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(GWColors.darkGray)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GWColors.gold.opacity(0.2), lineWidth: 1)
        )
    }
}
