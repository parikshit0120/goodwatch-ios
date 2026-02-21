import SwiftUI

// Screen 1: Intent Selector (Mood + Energy + Tags)
// Maps user selection to GWIntent with proper tags
struct MoodSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil

    @State private var selectedIndex: Int? = nil

    // Hardcoded fallback options (used when remote config hasn't loaded)
    // Each option maps to: (Mood, mood_key, Title, Subtitle, intent_tags, energy, cognitive_load)
    private static let fallbackOptions: [(Mood, String, String, String, [String], EnergyLevel, CognitiveLoad)] = [
        (.feelGood, "feel_good", "Feel-good", "Light and uplifting",
         ["feel_good", "uplifting", "safe_bet", "light", "calm"], .calm, .light),
        (.light, "easy_watch", "Easy watch", "Nothing too heavy",
         ["light", "background_friendly", "safe_bet", "calm"], .calm, .light),
        (.neutral, "surprise_me", "Surprise me", "I'm open to anything",
         [], .tense, .medium),
        (.intense, "gripping", "Gripping", "Edge of my seat",
         ["tense", "high_energy", "full_attention", "medium"], .high_energy, .medium),
        (.intense, "dark_heavy", "Dark & Heavy", "Hit me with the feels",
         ["dark", "bittersweet", "heavy", "full_attention", "acquired_taste"], .tense, .heavy)
    ]

    // Resolved options: remote display names if loaded, fallback otherwise
    // Mood enum, mood_key, display title, subtitle, intent_tags, energy, cognitive_load
    private var options: [(Mood, String, String, String, [String], EnergyLevel, CognitiveLoad)] {
        let remoteMappings = GWMoodConfigService.shared.allMappings
        let source = GWMoodConfigService.shared.configSource

        if source == "remote" && remoteMappings.count >= 5 {
            // Use remote display names but keep Mood enum + energy/cognitive_load from fallback
            return Self.fallbackOptions.enumerated().map { (index, fallback) in
                if index < remoteMappings.count {
                    let remote = remoteMappings[index]
                    return (
                        fallback.0, // Mood enum
                        remote.moodKey,
                        remote.displayName,
                        fallback.3, // subtitle stays hardcoded (not in remote config)
                        remote.compatibleTags,
                        fallback.5, // energy
                        fallback.6  // cognitive_load
                    )
                }
                return fallback
            }
        }

        return Self.fallbackOptions
    }

    // Representative movie poster for each mood — purely cosmetic
    // All live-action movies only — NO animated films
    private let moodPosters: [String] = [
        "/lBYOKAMcxIvuk9s9hMuecB9dPBV.jpg",  // Feel-good → The Pursuit of Happyness
        "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg",  // Easy watch
        "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",  // Surprise me
        "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg",  // Gripping
        "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg"   // Dark & Heavy → Fight Club
    ]

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(GWTypography.body(weight: .medium))
                        }
                        .foregroundColor(GWColors.lightGray)
                    }

                    Spacer()

                    AppLogo(size: 28)

                    Spacer()

                    Text("1/3")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)

                    if let onHome = onHome {
                        Button(action: onHome) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                                .foregroundColor(GWColors.lightGray)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.top, 16)

                Spacer().frame(height: 40)

                // Headline
                Text("What's the vibe?")
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 8)

                // Subhead
                Text("We'll match the mood")
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 32)

                // Mood Cards
                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        MoodCard(
                            title: option.2,
                            subtitle: option.3,
                            posterPath: moodPosters[index],
                            isSelected: selectedIndex == index,
                            action: {
                                selectedIndex = index
                                ctx.mood = option.0
                                // Set intent from selection using mood_key
                                ctx.intent = GWIntent(
                                    mood: option.1, // mood_key (e.g., "feel_good")
                                    energy: option.5,
                                    cognitive_load: option.6,
                                    intent_tags: option.4
                                )
                            }
                        )
                        .accessibilityIdentifier("mood_card_\(index)")
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Continue Button
                Button {
                    if let index = selectedIndex {
                        // SECTION 4: Immediately persist mood selection to Supabase
                        let option = options[index]
                        let moodString = option.1 // mood_key already in correct format
                        Task {
                            try? await UserService.shared.updateMoodPreference(moodString)
                        }
                        // Log mood config source for adoption tracking
                        MetricsService.shared.track(.sessionStart, properties: [
                            "mood_config_source": GWMoodConfigService.shared.configSource,
                            "mood_key": moodString
                        ])
                        // Persist onboarding step to Keychain for resume support
                        GWKeychainManager.shared.storeOnboardingStep(2)
                        ctx.saveToDefaults()
                        onNext()
                    }
                } label: {
                    Text("Continue")
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            selectedIndex != nil
                                ? AnyShapeStyle(LinearGradient.goldGradient)
                                : AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(selectedIndex == nil)
                .accessibilityIdentifier("mood_continue")
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }
}

struct MoodCard: View {
    let title: String
    let subtitle: String
    let posterPath: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Movie poster thumbnail on left edge
            GWCachedImage(url: TMDBImageSize.url(path: posterPath, size: .w154)) {
                Color.clear
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 72)
            .clipped()
            .opacity(0.9)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(GWColors.white)

                Text(subtitle)
                    .font(GWTypography.small())
                    .foregroundColor(GWColors.lightGray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72)
        .background(isSelected ? GWColors.darkGray : GWColors.darkGray.opacity(0.6))
        .cornerRadius(GWRadius.md)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.md)
                .stroke(isSelected ? GWColors.gold.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: isSelected ? GWColors.gold.opacity(0.15) : Color.clear, radius: 8)
        .onTapGesture {
            action()
        }
    }
}
