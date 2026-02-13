import SwiftUI

// Screen 1: Intent Selector (Mood + Energy + Tags)
// Maps user selection to GWIntent with proper tags
struct MoodSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil

    @State private var selectedIndex: Int? = nil

    // Each option maps to: (Mood, Title, Subtitle, intent_tags, energy, cognitive_load)
    let options: [(Mood, String, String, [String], EnergyLevel, CognitiveLoad)] = [
        (.feelGood, "Feel-good", "Light and uplifting",
         ["feel_good", "uplifting", "safe_bet", "light", "calm"], .calm, .light),
        (.light, "Easy watch", "Nothing too heavy",
         ["light", "background_friendly", "safe_bet", "calm"], .calm, .light),
        (.neutral, "Surprise me", "I'm open to anything",
         [], .tense, .medium),
        (.intense, "Gripping", "Edge of my seat",
         ["tense", "high_energy", "full_attention", "medium"], .high_energy, .medium),
        (.intense, "Dark & Heavy", "Hit me with the feels",
         ["dark", "bittersweet", "heavy", "full_attention", "acquired_taste"], .tense, .heavy)
    ]

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

                    Text("1/4")
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
                            title: option.1,
                            subtitle: option.2,
                            posterPath: moodPosters[index],
                            isSelected: selectedIndex == index,
                            action: {
                                selectedIndex = index
                                ctx.mood = option.0
                                // Set intent from selection
                                ctx.intent = GWIntent(
                                    mood: option.1.lowercased().replacingOccurrences(of: " ", with: "_"),
                                    energy: option.4,
                                    cognitive_load: option.5,
                                    intent_tags: option.3
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Continue Button
                Button {
                    if let index = selectedIndex {
                        // SECTION 4: Immediately persist mood selection to Supabase
                        let option = options[index]
                        let moodString = option.1.lowercased().replacingOccurrences(of: " ", with: "_")
                        Task {
                            try? await UserService.shared.updateMoodPreference(moodString)
                        }
                        // Persist onboarding step to Keychain for resume support
                        GWKeychainManager.shared.storeOnboardingStep(2)
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
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 72)
                        .clipped()
                        .opacity(0.9)
                default:
                    Color.clear
                        .frame(width: 56, height: 72)
                }
            }

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
