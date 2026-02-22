import SwiftUI

// Screen 2: Platform Selector
// 6 OTT platforms in a 3x2 grid with circular 3D design
// Languages are now selected on a separate LanguagePriorityView (v1.3)
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

                Spacer().frame(height: 40)

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
                        .accessibilityIdentifier("platform_\(platform.rawValue)")
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Continue Button - Fixed at bottom
                Button {
                    if !ctx.otts.isEmpty {
                        let platformStrings = ctx.otts.map { $0.rawValue }
                        Task {
                            try? await UserService.shared.updatePlatforms(platformStrings)
                        }
                        GWKeychainManager.shared.storeOnboardingStep(3)
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
                            !ctx.otts.isEmpty
                                ? AnyShapeStyle(LinearGradient.goldGradient)
                                : AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(ctx.otts.isEmpty)
                .accessibilityIdentifier("platform_continue")
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Pre-select from onboarding memory if available and fields are empty
            if ctx.otts.isEmpty, let saved = GWOnboardingMemory.shared.load() {
                ctx.otts = saved.otts
            }
        }
    }

    private func toggleSelectAll() {
        if ctx.otts.count == OTTPlatform.allCases.count {
            ctx.otts.removeAll()
        } else {
            ctx.otts = Array(OTTPlatform.allCases)
        }
    }

    private func togglePlatform(_ platform: OTTPlatform) {
        if ctx.otts.contains(platform) {
            ctx.otts.removeAll { $0 == platform }
        } else {
            ctx.otts.append(platform)
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

                    // Platform logo -- fills the circle with small margin
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
