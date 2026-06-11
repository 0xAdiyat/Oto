import SwiftUI

/// A grid of selectable option chips — the "10 mins / 20 mins / 30 mins /
/// 45 mins" selectors from the onboarding and Screen Breaks settings. Selected
/// chip gets a teal border + trailing checkmark, matching the LookAway flow but
/// in Oto's palette.
struct OptionChipGrid<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    var columns: Int = 2

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(options, id: \.value) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: (value: T, label: String)) -> some View {
        let isSelected = selection == option.value
        return Button {
            withAnimation(OtoUI.hoverEase) { selection = option.value }
        } label: {
            HStack(spacing: 6) {
                Text(option.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? OtoUI.primaryFG : OtoUI.secondaryFG)
                Spacer(minLength: 0)
                if isSelected {
                    OtoIcon(name: "checkmark", size: 11, weight: .semibold)
                        .foregroundStyle(Color.otoTeal)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.otoTeal.opacity(0.10) : OtoUI.rowIdle,
                in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.otoTeal.opacity(0.7) : OtoUI.dividerColor, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
