import SwiftUI

// Screen 1: Intent Selector (Mood + Energy + Tags)
// Maps user selection to GWIntent with proper tags
struct MoodSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedIndex: Int? = nil

    // Each option maps to: (Mood, Title, Subtitle, intent_tags, energy, cognitive_load)
    let options: [(Mood, String, String, [String], EnergyLevel, CognitiveLoad)] = [
        (.feelGood, "Feel-good", "Light and uplifting",
         ["feel_good", "uplifting", "safe_bet", "light", "calm"], .calm, .light),
        (.light, "Easy watch", "Nothing too heavy",
         ["light", "background_friendly", "safe_bet", "calm"], .calm, .light),
        (.neutral, "Surprise me", "I'm open to anything",
         ["safe_bet", "full_attention", "medium"], .tense, .medium),
        (.intense, "Gripping", "Edge of my seat",
         ["tense", "high_energy", "full_attention", "medium"], .high_energy, .medium),
        (.intense, "Dark & Heavy", "Hit me with the feels",
         ["dark", "bittersweet", "heavy", "full_attention", "acquired_taste"], .tense, .heavy)
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

                    Text("1/4")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GWColors.white)

            Text(subtitle)
                .font(GWTypography.small())
                .foregroundColor(GWColors.lightGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(isSelected ? GWColors.darkGray : GWColors.darkGray.opacity(0.6))
        .cornerRadius(GWRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.md)
                .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: isSelected ? Color.white.opacity(0.1) : Color.clear, radius: 8)
        .onTapGesture {
            action()
        }
    }
}
