import SwiftUI

// ============================================
// SORT MENU SHEET - Grouped radio button sort UI
// ============================================

struct SortMenuSheet: View {
    @Binding var selectedSort: SortOption

    @Environment(\.dismiss) private var dismiss

    private let sortGroups: [(icon: String, title: String, options: [SortOption])] = [
        ("★", "Rating", [.ratingDesc, .ratingAsc]),
        ("⏱", "Duration", [.durationDesc, .durationAsc]),
        ("📅", "Year", [.yearDesc, .yearAsc])
    ]

    var body: some View {
        NavigationView {
            ZStack {
                GWColors.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(sortGroups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Text(group.icon)
                                        .font(.system(size: 14))
                                    Text(group.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(GWColors.lightGray)
                                }
                                .padding(.leading, 4)

                                ForEach(group.options) { option in
                                    SortOptionRow(
                                        title: option.displayName.replacingOccurrences(of: "\(group.title): ", with: ""),
                                        isSelected: selectedSort == option,
                                        onSelect: {
                                            selectedSort = option
                                            dismiss()
                                        }
                                    )
                                }
                            }
                        }

                        // Reset button
                        if selectedSort != .ratingDesc {
                            Button {
                                selectedSort = .ratingDesc
                                dismiss()
                            } label: {
                                Text("Reset to default")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(GWColors.gold)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Sort by")
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
        .presentationDetents([.medium])
    }
}

struct SortOptionRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? GWColors.gold : GWColors.lightGray.opacity(0.5))

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GWColors.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? GWColors.gold.opacity(0.1) : GWColors.darkGray)
            .cornerRadius(GWRadius.md)
        }
    }
}
