import SwiftUI

/// A compact capsule segmented control matching the LookAway "Now / Stats"
/// toggle. Generic over any `Hashable` value so it serves the menu-bar genre
/// switch (Focus / Audio), the Now / Stats sub-tabs, and the onboarding
/// Posture / Blink toggle.
struct SegmentedPill<T: Hashable>: View {
    let items: [(value: T, label: String)]
    @Binding var selection: T
    var fillWidth: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.value) { item in
                let isSelected = selection == item.value
                Button {
                    withAnimation(OtoUI.hoverEase) { selection = item.value }
                } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: fillWidth ? .infinity : nil)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(isSelected ? OtoUI.rowSelected : Color.clear, in: Capsule())
                        .foregroundStyle(isSelected ? OtoUI.primaryFG : OtoUI.mutedFG)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(OtoUI.rowIdle, in: Capsule())
        .overlay { Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
    }
}
