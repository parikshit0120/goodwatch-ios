import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 72

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.5), radius: 20, x: 0, y: 10)
    }
}
