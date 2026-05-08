import SwiftUI

/// 30×30 icon button with subtle hover fill. Ported from media-downloader's
/// HistoryRowView.IconButton.
struct IconButton: View {
    let icon: String
    var size: CGFloat = OtoUI.iconButtonSize
    var iconSize: CGFloat = 14
    var help: String = ""
    var isSystemSymbol: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if isSystemSymbol {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                } else {
                    OtoIcon(name: icon, size: iconSize)
                }
            }
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous)
                    .fill(isHovering ? OtoUI.rowHover : OtoUI.rowIdle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }
}

/// Header-bar variant: transparent until hover, slightly larger icon.
struct HeaderIconButton: View {
    let icon: String
    var help: String = ""
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            OtoIcon(name: icon, size: 16)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous)
                        .fill(isHovering ? OtoUI.rowHover : Color.clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(OtoUI.secondaryFG)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }
}
