import SwiftUI

/// Renders SF Symbols at a fixed point size. Replaces the previous
/// asset-catalog-backed Lucide icons. Kept as a thin wrapper so the call
/// sites (`OtoIcon(name: "plus", size: 14)`) didn't all need to change.
struct OtoIcon: View {
    let name: String
    var size: CGFloat = 16
    var weight: Font.Weight = .regular

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .frame(width: size, height: size)
    }
}
