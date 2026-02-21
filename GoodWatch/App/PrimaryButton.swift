// DEPRECATED: Unused since v1.1. Gold gradient buttons replaced this.
// Kept for rollback reference. Not referenced by any active code path.

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
        .padding(.horizontal)
    }
}
