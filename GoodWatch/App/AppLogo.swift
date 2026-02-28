import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 72

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(GWColors.logoPill)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .shadow(color: GWColors.gold.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}
