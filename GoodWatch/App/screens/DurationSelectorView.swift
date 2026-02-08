import SwiftUI

// Screen 3: Duration Selector
// 3 duration cards matching the mockup
struct DurationSelectorView: View {
    @Binding var ctx: UserContext
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedDuration: DurationOption?
    @State private var seriesAvailabilityMessage: String?
    @State private var isCheckingSeriesAvailability = false

    enum DurationOption: CaseIterable {
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
            case .series: return 1  // Effectively no min for series (filtered by content_type instead)
            }
        }

        var maxDuration: Int {
            switch self {
            case .quick: return 90
            case .full: return 150
            case .series: return 999  // No max for series (use content_type filter)
            }
        }

        /// Whether this option requires series content (content_type = "series")
        var requiresSeries: Bool {
            self == .series
        }
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

                    Text("3/4")
                        .font(GWTypography.body(weight: .medium))
                        .foregroundColor(GWColors.lightGray)
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
                Text("We'll match the runtime")
                    .font(GWTypography.body())
                    .foregroundColor(GWColors.lightGray)
                    .padding(.horizontal, GWSpacing.screenPadding)

                Spacer().frame(height: 40)

                // Duration Cards
                VStack(spacing: 16) {
                    ForEach(DurationOption.allCases, id: \.self) { option in
                        DurationCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: selectedDuration == option,
                            isLoading: option == .series && isCheckingSeriesAvailability,
                            warningMessage: option == .series ? seriesAvailabilityMessage : nil,
                            action: {
                                selectedDuration = option
                                ctx.minDuration = option.minDuration
                                ctx.maxDuration = option.maxDuration
                                ctx.requiresSeries = option.requiresSeries

                                // Check series availability when selected
                                if option == .series {
                                    checkSeriesAvailability()
                                } else {
                                    seriesAvailabilityMessage = nil
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)

                Spacer()

                // Continue Button
                Button {
                    if let duration = selectedDuration {
                        // SECTION 4: Persist runtime to Supabase immediately
                        let runtimeRange: RuntimeRange = {
                            switch duration {
                            case .quick: return .short
                            case .full: return .long
                            case .series: return .any
                            }
                        }()
                        Task {
                            try? await UserService.shared.updateRuntimePreference(
                                maxRuntime: duration.maxDuration,
                                range: runtimeRange
                            )
                        }
                        // Persist onboarding step to Keychain for resume support
                        GWKeychainManager.shared.storeOnboardingStep(4)
                        onNext()
                    }
                } label: {
                    Text("Continue")
                        .font(GWTypography.button())
                        .foregroundColor(GWColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            selectedDuration == nil
                                ? AnyShapeStyle(GWColors.lightGray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient.goldGradient)
                        )
                        .cornerRadius(GWRadius.lg)
                }
                .disabled(selectedDuration == nil)
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Series Availability Check

    private func checkSeriesAvailability() {
        isCheckingSeriesAvailability = true
        seriesAvailabilityMessage = nil

        Task {
            // Get user's language and platform preferences
            let userLanguages = ctx.languages.map { $0.rawValue }

            // Skip check if no platforms/languages selected
            guard !ctx.otts.isEmpty, !ctx.languages.isEmpty else {
                await MainActor.run {
                    isCheckingSeriesAvailability = false
                }
                return
            }

            #if DEBUG
            print("🔍 Checking series availability for languages: \(userLanguages), platforms: \(ctx.otts.map { $0.rawValue })")
            #endif

            // Fetch series content from database
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
                print("❌ Series availability check failed: \(error)")
                #endif
                // On error, don't show warning - let user proceed
                await MainActor.run {
                    isCheckingSeriesAvailability = false
                }
                return
            }

            #if DEBUG
            print("📺 Found \(movies.count) series matching language filter")
            #endif

            // Filter by user's platforms using the same matching logic as the Movie model
            let matchingMovies = movies.filter { movie in
                guard let providers = movie.ott_providers, !providers.isEmpty else { return false }
                // Check if any provider matches any of the user's platforms
                return ctx.otts.contains { platform in
                    providers.contains { provider in provider.matches(platform) }
                }
            }

            #if DEBUG
            print("📺 Found \(matchingMovies.count) series matching platform filter")
            if !matchingMovies.isEmpty {
                print("   First match: \(matchingMovies[0].title)")
            }
            #endif

            await MainActor.run {
                isCheckingSeriesAvailability = false

                if matchingMovies.isEmpty {
                    // Build user-friendly message
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
                .background(GWColors.darkGray)
                .cornerRadius(GWRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.lg)
                        .stroke(isSelected ? GWColors.gold : Color.clear, lineWidth: 2)
                )
            }

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
