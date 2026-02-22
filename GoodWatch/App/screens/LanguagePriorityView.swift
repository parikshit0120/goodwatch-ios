import SwiftUI

// Screen 3: Language Priority (v1.3)
// Gamified funnel where users drag and drop languages in priority order.
// Max 4 languages, min 1 required. P1 = most preferred, affects scoring.
struct LanguagePriorityView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil

    @State private var selectedLanguages: [Language] = []
    @State private var showMoreLanguages = false

    // Lock animation state
    @State private var isLocking = false
    @State private var lockScale: CGFloat = 0
    @State private var funnelCompressed = false
    @State private var goldPulse = false

    // Drag reorder state
    @State private var draggingIndex: Int? = nil

    private let maxSlots = 4

    private let primaryLanguages: [Language] = [.hindi, .english, .tamil, .telugu, .malayalam, .kannada]
    private let secondaryLanguages: [Language] = [.bengali, .marathi, .gujarati, .punjabi, .korean, .japanese, .spanish]

    private var allVisibleLanguages: [Language] {
        showMoreLanguages ? primaryLanguages + secondaryLanguages : primaryLanguages
    }

    private var availableLanguages: [Language] {
        allVisibleLanguages.filter { !selectedLanguages.contains($0) }
    }

    private var slotWidths: [CGFloat] {
        let screenWidth = UIScreen.main.bounds.width
        return [
            screenWidth - 48,    // P1: nearly full width
            screenWidth - 88,    // P2
            screenWidth - 128,   // P3
            screenWidth - 168    // P4: narrowest
        ]
    }

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

                    Text("3/4")
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
                        Spacer().frame(height: 24)

                        // Headline
                        Text("What do you watch in?")
                            .font(GWTypography.headline())
                            .foregroundColor(GWColors.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 6)

                        // Subtext
                        Text("Tap to add. Top = most preferred.")
                            .font(GWTypography.body())
                            .foregroundColor(GWColors.lightGray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 24)

                        // Available Languages Pool
                        languagePool

                        Spacer().frame(height: 28)

                        // Priority Funnel
                        priorityFunnel
                            .padding(.horizontal, GWSpacing.screenPadding)

                        Spacer().frame(height: 24)
                    }
                }

                // Lock Priority Button - Fixed at bottom
                Button(action: lockAndProceed) {
                    Text("Lock Priority")
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            selectedLanguages.isEmpty
                                ? AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient.goldGradient)
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(selectedLanguages.isEmpty || isLocking)
                .accessibilityIdentifier("language_lock")
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 40)
            }

            // Lock icon overlay
            if isLocking {
                Color.black.opacity(goldPulse ? 0.4 : 0.0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(GWColors.gold)
                    .scaleEffect(lockScale)
                    .rotation3DEffect(.degrees(Double(lockScale) * 360), axis: (x: 0, y: 1, z: 0))
                    .shadow(color: GWColors.gold.opacity(0.5), radius: 20)
            }
        }
        .onAppear {
            // Pre-select from onboarding memory or context if available
            if selectedLanguages.isEmpty {
                if !ctx.languages.isEmpty {
                    selectedLanguages = Array(ctx.languages.prefix(maxSlots))
                } else if let saved = GWOnboardingMemory.shared.load() {
                    selectedLanguages = Array(saved.languages.prefix(maxSlots))
                }
            }
            // Auto-expand if a secondary language was previously selected
            if selectedLanguages.contains(where: { secondaryLanguages.contains($0) }) {
                showMoreLanguages = true
            }
        }
        .allowsHitTesting(!isLocking)
    }

    // MARK: - Language Pool (horizontal scrollable chips)

    @ViewBuilder
    private var languagePool: some View {
        VStack(spacing: 12) {
            // Primary row + More button
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableLanguages, id: \.self) { language in
                        let isAvailable = OTTLanguageAvailability.shared.isLanguageAvailable(language, onPlatforms: ctx.otts)
                        Button {
                            if isAvailable || ctx.otts.isEmpty {
                                addLanguage(language)
                            }
                        } label: {
                            Text(language.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(
                                    (!isAvailable && !ctx.otts.isEmpty) ? GWColors.lightGray.opacity(0.4) : GWColors.white
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(GWColors.darkGray.opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(GWColors.surfaceBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity((!isAvailable && !ctx.otts.isEmpty) ? 0.5 : 1.0)
                    }

                    // More/Fewer toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showMoreLanguages.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showMoreLanguages ? "Less" : "More")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: showMoreLanguages ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(GWColors.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)
            }
        }
    }

    // MARK: - Priority Funnel

    @ViewBuilder
    private var priorityFunnel: some View {
        VStack(spacing: funnelCompressed ? 4 : 12) {
            ForEach(0..<maxSlots, id: \.self) { index in
                let language = index < selectedLanguages.count ? selectedLanguages[index] : nil
                FunnelSlot(
                    index: index,
                    language: language,
                    width: slotWidths[index],
                    onRemove: {
                        removeLanguage(at: index)
                    },
                    onMoveUp: index > 0 ? {
                        moveLanguage(from: index, to: index - 1)
                    } : nil,
                    onMoveDown: (index < selectedLanguages.count - 1) ? {
                        moveLanguage(from: index, to: index + 1)
                    } : nil
                )
                .opacity(goldPulse && language != nil ? 1.0 : (language != nil ? 1.0 : 0.6))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLanguages)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addLanguage(_ language: Language) {
        guard selectedLanguages.count < maxSlots else { return }
        guard !selectedLanguages.contains(language) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedLanguages.append(language)
        }
    }

    private func removeLanguage(at index: Int) {
        guard index < selectedLanguages.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedLanguages.remove(at: index)
        }
    }

    private func moveLanguage(from source: Int, to destination: Int) {
        guard source < selectedLanguages.count, destination < selectedLanguages.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let item = selectedLanguages.remove(at: source)
            selectedLanguages.insert(item, at: destination)
        }
    }

    // MARK: - Lock Animation

    private func lockAndProceed() {
        guard !selectedLanguages.isEmpty, !isLocking else { return }

        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Step 1: Compress funnel
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            funnelCompressed = true
        }

        // Step 2: Gold pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                goldPulse = true
            }
        }

        // Step 3: Lock icon appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                lockScale = 1.0
                isLocking = true
            }
        }

        // Step 4: Navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Save languages in priority order to context
            ctx.languages = selectedLanguages
            let languageStrings = selectedLanguages.map { $0.rawValue }
            Task {
                try? await UserService.shared.updateLanguages(languageStrings)
            }
            ctx.saveToDefaults()
            onNext()
        }
    }
}

// MARK: - Funnel Slot

struct FunnelSlot: View {
    let index: Int
    let language: Language?
    let width: CGFloat
    var onRemove: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    var body: some View {
        ZStack {
            if let lang = language {
                // Filled slot
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(GWColors.gold)
                        .frame(width: 30)

                    Spacer().frame(width: 12)

                    Text(lang.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Reorder buttons
                    if let moveUp = onMoveUp {
                        Button(action: moveUp) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GWColors.lightGray)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }

                    if let moveDown = onMoveDown {
                        Button(action: moveDown) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GWColors.lightGray)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }

                    // Remove button
                    Button {
                        onRemove?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(GWColors.lightGray)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GWColors.gold.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(GWColors.gold.opacity(0.3), lineWidth: 1.5)
                        )
                )
            } else {
                // Empty slot
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(GWColors.lightGray.opacity(0.4))
                        .frame(width: 30)

                    Spacer().frame(width: 12)

                    Text("Tap a language above")
                        .font(.system(size: 14))
                        .foregroundColor(GWColors.lightGray.opacity(0.4))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                        .foregroundColor(GWColors.lightGray.opacity(0.2))
                )
            }
        }
    }
}
