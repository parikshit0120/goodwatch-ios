import SwiftUI

// ============================================
// UPDATE BANNER — Non-blocking gold banner
// ============================================
// Shows at the top of the screen when a new App Store version is available.
// "Update Available" with Update / Dismiss buttons.
// Uses the GoodWatch gold gradient to stay on-brand.
// Non-blocking: user can dismiss and continue using the app.
// ============================================

struct GWUpdateBanner: View {
    @ObservedObject var checker: GWUpdateChecker

    var body: some View {
        if checker.updateAvailable {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient.goldGradient)

                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Available")
                            .font(GWTypography.small(weight: .semibold))
                            .foregroundColor(GWColors.white)

                        if let version = checker.latestVersion {
                            Text("Version \(version) is ready")
                                .font(GWTypography.tiny(weight: .regular))
                                .foregroundColor(GWColors.lightGray)
                        }
                    }

                    Spacer()

                    // Update button
                    Button {
                        if let url = checker.storeURL {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Update")
                            .font(GWTypography.tiny(weight: .semibold))
                            .foregroundColor(GWColors.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(LinearGradient.goldGradient)
                            .cornerRadius(GWRadius.full)
                    }

                    // Dismiss button
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            checker.dismissUpdate()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GWColors.lightGray)
                            .frame(width: 28, height: 28)
                            .background(GWColors.darkGray)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, GWSpacing.screenPadding)
                .padding(.vertical, 12)
                .background(Color(hex: "1A1A1A"))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GWColors.gold.opacity(0.3), GWColors.gold.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ),
                    alignment: .bottom
                )
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
