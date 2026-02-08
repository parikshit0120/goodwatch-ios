import SwiftUI

// Screen 7: Rejection Flow (Bottom Sheet)
// "No problem. Why not tonight?"
struct RejectionSheetView: View {
    let onReason: (RejectionReason) -> Void
    let onJustShowAnother: () -> Void
    let onDismiss: () -> Void

    enum RejectionReason: String, CaseIterable {
        case tooLong = "Too long"
        case notInMood = "Not in the mood"
        case notInterested = "Not interested"
    }

    var body: some View {
        ZStack {
            // Overlay (tap to dismiss)
            GWColors.overlay
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Sheet
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GWColors.lightGray.opacity(0.4))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    // Gentle helper text
                    Text("This helps us get better.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(GWColors.lightGray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 12)

                    // Headline
                    Text("No problem.")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(GWColors.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 4)

                    // Subheading
                    Text("Why not tonight?")
                        .font(GWTypography.body())
                        .foregroundColor(GWColors.lightGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 24)

                    // Reason Buttons
                    VStack(spacing: 12) {
                        ForEach(RejectionReason.allCases, id: \.self) { reason in
                            ReasonButton(title: reason.rawValue) {
                                onReason(reason)
                            }
                        }
                    }
                    .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 20)

                    // Divider
                    Rectangle()
                        .fill(GWColors.surfaceBorder)
                        .frame(height: 1)
                        .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 16)

                    // "Just show me another" button
                    Button {
                        onJustShowAnother()
                    } label: {
                        Text("Just show me another")
                            .font(GWTypography.body(weight: .semibold))
                            .foregroundColor(GWColors.lightGray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: GWRadius.md)
                                    .stroke(GWColors.surfaceBorder, lineWidth: 1.5)
                            )
                            .cornerRadius(GWRadius.md)
                    }
                    .padding(.horizontal, GWSpacing.screenPadding)

                    Spacer().frame(height: 32)
                }
                .background(GWColors.darkGray)
                .cornerRadius(GWRadius.xl, corners: [.topLeft, .topRight])
            }
            .transition(.move(edge: .bottom))
        }
    }
}

struct ReasonButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GWTypography.body(weight: .medium))
                .foregroundColor(GWColors.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: GWRadius.md)
                        .stroke(GWColors.surfaceBorder, lineWidth: 1.5)
                )
                .cornerRadius(GWRadius.md)
        }
    }
}

// Extension for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
