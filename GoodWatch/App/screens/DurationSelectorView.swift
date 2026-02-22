import SwiftUI

// Screen 3: Duration Selector
// Multi-select: user can pick multiple duration options to widen the pool
struct DurationSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil

    @State private var selectedDurations: Set<DurationOption> = []
    @State private var seriesAvailabilityMessage: String?
    @State private var isCheckingSeriesAvailability = false

    enum DurationOption: String, CaseIterable, Hashable {
        case quick      // 90 minutes
        case full       // 2-2.5 hours
        case series     // Series/Binge

        var title: String {
            switch self {
            case .quick: return "90 minutes"
            case .full: return "2-2.5 hours"
            case .series: return "Series/Binge"
            }
        }

        var subtitle: String {
            switch self {
            case .quick: return "Quick watch"
            case .full: return "Full movie experience"
            case .series: return "Multiple episodes"
            }
        }

        var minDuration: Int {
            switch self {
            case .quick: return 60
            case .full: return 120
            case .series: return 1
            }
        }

        var maxDuration: Int {
            switch self {
            case .quick: return 90
            case .full: return 150
            case .series: return 999
            }
        }

        var requiresSeries: Bool {
            self == .series
        }
    }

    /// Compute the union runtime range from all selected options
    private func computeUnionRange() -> (min: Int, max: Int) {
        var lo = Int.max
        var hi = 0
        for d in selectedDurations {
            lo = min(lo, d.minDuration)
            hi = max(hi, d.maxDuration)
        }
        return (min: lo == Int.max ? 60 : lo, max: hi == 0 ? 150 : hi)
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

                    Text("4/4")
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
                Text("How long do you want\nto watch?")
                    .font(GWTypography.headline())
                    .foregroundColor(GWColors.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 8)

                // Subhead
                Text("Select all that work")
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 40)

                // Duration Cards
                VStack(spacing: 16) {
                    ForEach(Array(DurationOption.allCases.enumerated()), id: \.element) { index, option in
                        DurationCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: selectedDurations.contains(option),
                            isLoading: option == .series && isCheckingSeriesAvailability,
                            warningMessage: option == .series ? seriesAvailabilityMessage : nil,
                            action: {
                                toggleDuration(option)
                            }
                        )
                        .accessibilityIdentifier("duration_card_\(index)")
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Continue Button
                Button {
                    if !selectedDurations.isEmpty {
                        let range = computeUnionRange()
                        ctx.minDuration = range.min
                        ctx.maxDuration = range.max
                        ctx.requiresSeries = selectedDurations.contains(.series)

                        // Persist to Supabase
                        let runtimeRange: RuntimeRange = {
                            if selectedDurations.contains(.series) { return .any }
                            if selectedDurations.count > 1 { return .any }
                            if selectedDurations.contains(.quick) { return .short }
                            return .long
                        }()
                        Task {
                            try? await UserService.shared.updateRuntimePreference(
                                maxRuntime: range.max,
                                range: runtimeRange
                            )
                        }
                        GWKeychainManager.shared.storeOnboardingStep(4)
                        ctx.saveToDefaults()
                        onNext()
                    }
                } label: {
                    Text("Continue")
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            selectedDurations.isEmpty
                                ? AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient.goldGradient)
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(selectedDurations.isEmpty)
                .accessibilityIdentifier("duration_continue")
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Pre-select from onboarding memory if available
            if selectedDurations.isEmpty, let saved = GWOnboardingMemory.shared.load() {
                if saved.requiresSeries {
                    selectedDurations.insert(.series)
                }
                if saved.maxDuration <= 90 || saved.minDuration < 120 {
                    selectedDurations.insert(.quick)
                }
                if saved.maxDuration >= 120 && saved.maxDuration <= 150 {
                    selectedDurations.insert(.full)
                }
                // If nothing matched, default to full
                if selectedDurations.isEmpty {
                    selectedDurations.insert(.full)
                }
                ctx.minDuration = saved.minDuration
                ctx.maxDuration = saved.maxDuration
                ctx.requiresSeries = saved.requiresSeries
            }
        }
    }

    // MARK: - Toggle Duration

    private func toggleDuration(_ option: DurationOption) {
        if selectedDurations.contains(option) {
            // Don't allow empty — at least 1 must be selected
            if selectedDurations.count > 1 {
                selectedDurations.remove(option)
            }
        } else {
            selectedDurations.insert(option)
        }

        // Update context with union range
        let range = computeUnionRange()
        ctx.minDuration = range.min
        ctx.maxDuration = range.max
        ctx.requiresSeries = selectedDurations.contains(.series)

        // Check series availability when selected
        if option == .series && selectedDurations.contains(.series) {
            checkSeriesAvailability()
        } else if !selectedDurations.contains(.series) {
            seriesAvailabilityMessage = nil
        }
    }

    // MARK: - Series Availability Check

    private func checkSeriesAvailability() {
        isCheckingSeriesAvailability = true
        seriesAvailabilityMessage = nil

        Task {
            let userLanguages = ctx.languages.map { $0.rawValue }

            guard !ctx.otts.isEmpty, !ctx.languages.isEmpty else {
                await MainActor.run {
                    isCheckingSeriesAvailability = false
                }
                return
            }

            #if DEBUG
            print("[DURATION] Checking series availability for languages: \(userLanguages)")
            #endif

            let movies: [Movie]
            do {
                movies = try await SupabaseService.shared.fetchMoviesForAvailabilityCheck(
                    languages: userLanguages,
                    contentType: "tv",
                    acceptCount: 0,
                    limit: 100
                )
            } catch {
                #if DEBUG
                print("[DURATION] Series availability check failed: \(error)")
                #endif
                await MainActor.run {
                    isCheckingSeriesAvailability = false
                }
                return
            }

            let matchingMovies = movies.filter { movie in
                guard let providers = movie.ott_providers, !providers.isEmpty else { return false }
                return ctx.otts.contains { platform in
                    providers.contains { provider in provider.matches(platform) }
                }
            }

            await MainActor.run {
                isCheckingSeriesAvailability = false

                if matchingMovies.isEmpty {
                    let platformNames = ctx.otts.map { $0.displayName }.joined(separator: ", ")
                    let langNames = ctx.languages.map { $0.displayName }.joined(separator: ", ")
                    seriesAvailabilityMessage = "Limited series in \(langNames) on \(platformNames). Try movies instead."
                } else {
                    seriesAvailabilityMessage = nil
                }
            }
        }
    }
}

struct DurationCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var isLoading: Bool = false
    var warningMessage: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(GWColors.white)

                        if isLoading {
                            ProgressView()
                                .tint(GWColors.lightGray)
                                .scaleEffect(0.8)
                        }
                    }

                    Text(subtitle)
                        .font(GWTypography.small())
                        .foregroundColor(GWColors.lightGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(isSelected ? GWColors.darkGray : GWColors.darkGray.opacity(0.6))
                .cornerRadius(GWRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.lg)
                        .stroke(isSelected ? GWColors.gold : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            // Warning message for series availability
            if let warning = warningMessage, isSelected {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(GWColors.gold)

                    Text(warning)
                        .font(.system(size: 12))
                        .foregroundColor(GWColors.lightGray)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "2A2A2A"))
                .cornerRadius(8)
            }
        }
    }
}
