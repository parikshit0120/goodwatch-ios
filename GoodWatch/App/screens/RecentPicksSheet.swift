import SwiftUI

// Screen: Recent Picks Bottom Sheet
// Auto-shows on app launch if recent picks exist.
// Tap-to-dismiss overlay + scrollable list of up to 5 recent recommendations.
struct RecentPicksSheet: View {
    let picks: [RecentPicksService.RecentPick]
    let onDismiss: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Tap-to-dismiss background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }

                // Sheet content — pinned to bottom, ~60% height
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GWColors.lightGray.opacity(0.4))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    // Header row
                    HStack {
                        Text("Recent Picks")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GWColors.white)

                        Spacer()

                        Button {
                            onClearAll()
                        } label: {
                            Text("Clear All")
                                .font(GWTypography.small(weight: .medium))
                                .foregroundColor(GWColors.lightGray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 4)

                    Text("Jump back to a recent recommendation")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(GWColors.lightGray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 20)

                    // Pick rows — scrollable
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(picks) { pick in
                                RecentPickRow(pick: pick)
                            }
                        }
                        .padding(.horizontal, GWSpacing.screenPadding)
                    }
                    .frame(maxHeight: geometry.size.height * 0.4)

                    Spacer().frame(height: 32)
                }
                .frame(maxHeight: geometry.size.height * 0.6)
                .background(
                    GWColors.darkGray
                        .onTapGesture {
                            // Prevent taps on sheet from dismissing
                        }
                )
                .cornerRadius(GWRadius.xl, corners: [.topLeft, .topRight])
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Single Pick Row

struct RecentPickRow: View {
    let pick: RecentPicksService.RecentPick

    var body: some View {
        HStack(spacing: 14) {
            // Poster thumbnail
            if let urlString = pick.posterURL {
                GWCachedImage(url: urlString) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GWColors.subtleFill)
                        .frame(width: 60, height: 90)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 90)
                .clipped()
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(GWColors.subtleFill)
                    .frame(width: 60, height: 90)
            }

            // Title + score
            VStack(alignment: .leading, spacing: 6) {
                Text(pick.title)
                    .font(GWTypography.body(weight: .medium))
                    .foregroundColor(GWColors.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("\(pick.goodScore)")
                        .font(GWTypography.small(weight: .bold))
                        .foregroundStyle(LinearGradient.goldGradient)

                    Text("GoodScore")
                        .font(GWTypography.tiny(weight: .regular))
                        .foregroundColor(GWColors.lightGray)
                }
            }

            Spacer()

            // Watch button (if platform link available)
            if pick.hasWatchLink {
                Button {
                    openWatchLink(pick: pick)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))

                        if let platform = pick.platformDisplayName {
                            Text(platform)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(GWColors.black)
                    .frame(width: 56, height: 44)
                    .background(LinearGradient.goldGradient)
                    .cornerRadius(GWRadius.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(GWColors.subtleInteractiveFill)
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.md)
                .stroke(GWColors.surfaceBorder, lineWidth: 1)
        )
        .cornerRadius(GWRadius.md)
    }

    private func openWatchLink(pick: RecentPicksService.RecentPick) {
        // Try deeplink first, then fall back to web URL
        if let deepLink = pick.deepLinkURL, let url = URL(string: deepLink) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // App not installed — fall back to web
                    if let webString = pick.webURL, let webUrl = URL(string: webString) {
                        UIApplication.shared.open(webUrl)
                    }
                }
            }
        } else if let webString = pick.webURL, let url = URL(string: webString) {
            UIApplication.shared.open(url)
        }
    }
}
