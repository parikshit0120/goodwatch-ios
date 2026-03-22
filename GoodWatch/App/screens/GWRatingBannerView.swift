import SwiftUI

// ============================================
// GWRatingBannerView — "How was it?" Post-Watch Banner
// ============================================
//
// Non-blocking banner shown on return sessions for unrated accepted movies.
// User taps thumbs up or thumbs down. Shows confirmation then auto-dismisses.
// ============================================

struct GWRatingBannerView: View {
    let pending: PendingRating
    let onRate: (Bool) -> Void  // true = thumbs up, false = thumbs down
    let onDismiss: () -> Void

    @State private var showConfirmation: Bool = false
    @State private var confirmationText: String = ""

    var body: some View {
        if showConfirmation {
            // Post-rating confirmation (auto-dismisses after 2 seconds)
            Text(confirmationText)
                .font(GWTypography.small(weight: .medium))
                .foregroundColor(GWColors.lightGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(GWColors.surfaceElevated)
                .cornerRadius(GWRadius.md)
                .padding(.horizontal, 16)
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            onDismiss()
                        }
                    }
                }
        } else {
            HStack(spacing: 12) {
                // Movie poster thumbnail
                if let posterPath = pending.posterPath, !posterPath.isEmpty {
                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(GWColors.surfaceSecondary)
                    }
                    .frame(width: 40, height: 60)
                    .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("How was \(pending.movieTitle)?")
                        .font(GWTypography.small(weight: .medium))
                        .foregroundColor(GWColors.white)
                        .lineLimit(1)

                    Text("Your feedback helps us get better for you")
                        .font(GWTypography.tiny())
                        .foregroundColor(GWColors.lightGray)
                }

                Spacer()

                // Thumbs up button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        confirmationText = "Got it -- we'll show you more like this"
                        showConfirmation = true
                    }
                    onRate(true)
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.title3)
                        .foregroundColor(GWColors.gold)
                }

                // Thumbs down button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        confirmationText = "Noted -- we'll adjust your picks"
                        showConfirmation = true
                    }
                    onRate(false)
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.title3)
                        .foregroundColor(GWColors.lightGray)
                }
            }
            .padding(12)
            .background(GWColors.surfaceElevated)
            .cornerRadius(GWRadius.md)
            .padding(.horizontal, 16)
        }
    }
}
