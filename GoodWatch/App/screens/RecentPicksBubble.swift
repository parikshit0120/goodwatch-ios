import SwiftUI

// Floating bubble for Recent Picks — bottom-right corner.
// Shows after the launch sheet is dismissed. Tap to re-open sheet.
struct RecentPicksBubble: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button(action: onTap) {
                    ZStack(alignment: .topTrailing) {
                        // Main circle
                        Circle()
                            .fill(LinearGradient.goldGradient)
                            .frame(width: 48, height: 48)
                            .shadow(color: GWColors.gold.opacity(0.4), radius: 8, x: 0, y: 4)
                            .overlay(
                                Image(systemName: "film.stack")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(GWColors.logoPill)
                            )

                        // Count badge
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(GWColors.logoPill)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.5)))
    }
}
