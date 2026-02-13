import SwiftUI

// ============================================
// FILTER SHEET - Multi-select filter UI
// ============================================

struct FilterSheet: View {
    let title: String
    let options: [String]
    @Binding var selected: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                GWColors.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            FilterOptionRow(
                                title: option,
                                isSelected: selected.contains(option),
                                onToggle: {
                                    if selected.contains(option) {
                                        selected.remove(option)
                                    } else {
                                        selected.insert(option)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(GWColors.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct FilterOptionRow: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GWColors.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? GWColors.gold : GWColors.lightGray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? GWColors.gold.opacity(0.1) : GWColors.darkGray)
            .cornerRadius(GWRadius.md)
        }
    }
}
