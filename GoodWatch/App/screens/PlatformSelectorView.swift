import SwiftUI

// Screen 2: Platform Selector
// 6 OTT platforms in a 3x2 grid with circular 3D design
struct PlatformSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil

    let platformColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    let languageColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            GWColors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - Fixed at top
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

                    Text("2/4")
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

                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 20)

                        // Headline
                        Text("Which platforms do you have?")
                            .font(GWTypography.headline())
                            .foregroundColor(GWColors.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 6)

                        // Subhead
                        Text("We'll only show films you can watch")
                            .font(GWTypography.body())
                            .foregroundColor(GWColors.lightGray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 20)

                        // Select All / Deselect All toggle
                        HStack {
                            Spacer()
                            Button {
                                toggleSelectAll()
                            } label: {
                                Text(ctx.otts.count == OTTPlatform.allCases.count ? "Deselect all" : "Select all")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GWColors.gold)
                            }
                        }
                        .padding(.horizontal, GWSpacing.screenPadding)
                        .padding(.bottom, 8)

                        // Platform Grid - Circular 3D Design
                        LazyVGrid(columns: platformColumns, spacing: 16) {
                            ForEach(OTTPlatform.allCases, id: \.self) { platform in
                                PlatformTile(
                                    platform: platform,
                                    isSelected: ctx.otts.contains(platform),
                                    action: {
                                        togglePlatform(platform)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 28)

                        // Language Section - Visually distinct card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Preferred language")
                                .font(GWTypography.headline())
                                .foregroundColor(GWColors.white)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("Select languages you'd like to watch in")
                                .font(GWTypography.body())
                                .foregroundColor(GWColors.lightGray)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Spacer().frame(height: 4)

                            LazyVGrid(columns: languageColumns, spacing: 12) {
                                ForEach(Language.visibleCases, id: \.self) { language in
                                    let isAvailable = OTTLanguageAvailability.shared.isLanguageAvailable(language, onPlatforms: ctx.otts)
                                    LanguageChip(
                                        language: language,
                                        isSelected: ctx.languages.contains(language),
                                        isDisabled: !isAvailable && !ctx.otts.isEmpty,
                                        unavailabilityHint: !isAvailable && !ctx.otts.isEmpty
                                            ? OTTLanguageAvailability.shared.unavailabilityMessage(for: language, onPlatforms: ctx.otts)
                                            : nil,
                                        action: {
                                            toggleLanguage(language)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "1A1A1A"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(GWColors.surfaceBorder.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 16)
                    }
                }

                // Continue Button - Fixed at bottom with safe area
                Button {
                    if canProceed {
                        let platformStrings = ctx.otts.map { $0.rawValue }
                        let languageStrings = ctx.languages.map { $0.rawValue }
                        Task {
                            try? await UserService.shared.updatePlatforms(platformStrings)
                            try? await UserService.shared.updateLanguages(languageStrings)
                        }
                        GWKeychainManager.shared.storeOnboardingStep(3)
                        onNext()
                    }
                } label: {
                    Text("Continue")
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            canProceed
                                ? AnyShapeStyle(LinearGradient.goldGradient)
                                : AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(!canProceed)
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 16)
                .background(GWColors.black)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    private var canProceed: Bool {
        !ctx.otts.isEmpty && !ctx.languages.isEmpty
    }

    private func toggleSelectAll() {
        if ctx.otts.count == OTTPlatform.allCases.count {
            // Deselect all
            ctx.otts.removeAll()
        } else {
            // Select all
            ctx.otts = Array(OTTPlatform.allCases)
        }
        // Re-validate languages against new platform set
        if !ctx.otts.isEmpty {
            ctx.languages.removeAll { language in
                !OTTLanguageAvailability.shared.isLanguageAvailable(language, onPlatforms: ctx.otts)
            }
        }
    }

    private func togglePlatform(_ platform: OTTPlatform) {
        if ctx.otts.contains(platform) {
            ctx.otts.removeAll { $0 == platform }
        } else {
            ctx.otts.append(platform)
        }

        // Auto-deselect languages that are no longer available on selected platforms
        if !ctx.otts.isEmpty {
            ctx.languages.removeAll { language in
                !OTTLanguageAvailability.shared.isLanguageAvailable(language, onPlatforms: ctx.otts)
            }
        }
    }

    private func toggleLanguage(_ language: Language) {
        // Don't allow selecting unavailable languages
        if !ctx.otts.isEmpty && !OTTLanguageAvailability.shared.isLanguageAvailable(language, onPlatforms: ctx.otts) {
            return
        }

        if ctx.languages.contains(language) {
            ctx.languages.removeAll { $0 == language }
        } else {
            ctx.languages.append(language)
        }
    }
}

struct LanguageChip: View {
    let language: Language
    let isSelected: Bool
    var isDisabled: Bool = false
    var unavailabilityHint: String? = nil
    let action: () -> Void

    @State private var showHint = false

    var body: some View {
        VStack(spacing: 4) {
            Button {
                if isDisabled {
                    // Show hint when tapping disabled chip
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHint = true
                    }
                    // Auto-hide after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHint = false
                        }
                    }
                } else {
                    action()
                }
            } label: {
                Text(language.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDisabled ? GWColors.lightGray.opacity(0.5) : GWColors.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isDisabled ? GWColors.darkGray.opacity(0.3) : (isSelected ? GWColors.darkGray : GWColors.darkGray.opacity(0.6)))
                    .cornerRadius(GWRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: GWRadius.md)
                            .stroke(
                                isDisabled
                                    ? GWColors.surfaceBorder.opacity(0.3)
                                    : (isSelected ? GWColors.gold.opacity(0.6) : GWColors.surfaceBorder),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: isSelected && !isDisabled ? GWColors.gold.opacity(0.15) : Color.clear, radius: 8)
            }
            .buttonStyle(.plain)

            // Unavailability hint appears below the chip
            if showHint, let hint = unavailabilityHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(GWColors.lightGray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(GWColors.darkGray.opacity(0.9))
                    .cornerRadius(4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

struct PlatformTile: View {
    let platform: OTTPlatform
    let isSelected: Bool
    let action: () -> Void

    private let circleSize: CGFloat = 80

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Circular 3D container
                ZStack {
                    // 3D Circle with gradient background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "2C2C2E"),
                                    Color(hex: "1C1C1E")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            // Inner highlight for 3D effect
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            // Selection border - light golden outline
                            Circle()
                                .stroke(
                                    isSelected ? GWColors.gold.opacity(0.7) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .shadow(color: isSelected ? GWColors.gold.opacity(0.2) : Color.clear, radius: 12, x: 0, y: 0)

                    // Platform logo — fills the circle with small margin
                    Image(platformLogoName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())
                }

                // Platform name
                Text(platform.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GWColors.white)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var platformLogoName: String {
        switch platform {
        case .netflix: return "netflix_logo"
        case .prime: return "prime_logo"
        case .jioHotstar: return "hotstar_logo"
        case .appleTV: return "appletv_logo"
        case .sonyLIV: return "sonyliv_logo"
        case .zee5: return "zee5_logo"
        }
    }
}
