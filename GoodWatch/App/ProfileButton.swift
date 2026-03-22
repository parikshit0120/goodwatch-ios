import SwiftUI

// ============================================
// PROFILE BUTTON - Reusable header component
// ============================================
// Shows person.fill icon. Tapping opens ProfileTab as a sheet.
// Place next to the home button in screen headers.

struct ProfileButton: View {
    var onSignOut: (() -> Void)?
    var iconSize: CGFloat = 14

    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.fill")
                .font(.system(size: iconSize))
                .foregroundColor(GWColors.lightGray)
        }
        .sheet(isPresented: $showProfile) {
            ProfileTab(onSignOut: {
                showProfile = false
                onSignOut?()
            })
            .presentationDragIndicator(.visible)
        }
    }
}
