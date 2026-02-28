import SwiftUI

struct QualityRelaxedBannerView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
                .foregroundColor(GWColors.gold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Slim pickings for this combo")
                    .font(GWTypography.small(weight: .bold))
                    .foregroundColor(GWColors.white)

                Text("Your filters are pretty specific -- this is the best match we found, but it's not rated as highly as our usual picks. Try a different mood or platform for better options.")
                    .font(GWTypography.tiny())
                    .foregroundColor(GWColors.lightGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GWColors.gold.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: GWRadius.md)
                .stroke(GWColors.gold.opacity(0.20), lineWidth: 1)
        )
        .cornerRadius(GWRadius.md)
        .padding(.horizontal, GWSpacing.screenPadding)
        .padding(.bottom, 12)
    }
}
