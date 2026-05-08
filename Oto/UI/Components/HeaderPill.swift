import AppKit
import SwiftUI

/// Capsule "title bar" sitting at the top of the spotlight panel.
/// Logo + title + status dot + hover-revealed action cluster.
struct HeaderPill: View {
    @Environment(AppState.self) private var state
    let onAdd: () -> Void
    let onTemplates: () -> Void
    let onShowProfiles: () -> Void
    let onShowDevices: () -> Void
    let onShowSettings: () -> Void
    let onShowAbout: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image("LogoFull")
                .resizable()
                .scaledToFit()
                .frame(height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Rules")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(state.store.rules.filter(\.enabled).count) of \(state.store.rules.count) active")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            Spacer()

            profilePicker

            HStack(spacing: 6) {
                Circle().fill(Color.otoTeal).frame(width: 7, height: 7)
                Text("Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OtoUI.secondaryFG)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(OtoUI.rowIdle, in: Capsule())

            HStack(spacing: 4) {
                HeaderIconButton(icon: "plus", help: "Add rule", action: onAdd)
                HeaderIconButton(icon: "wand-sparkles", help: "Templates", action: onTemplates)
                HeaderIconButton(icon: "ellipsis", help: "More", action: showOverflowMenu)
            }
            .opacity(isHovering ? 1 : 0.55)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .frame(width: OtoUI.pillWidth, height: OtoUI.pillHeight)
        .materialCapsule()
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var profilePicker: some View {
        Menu {
            Button {
                state.store.activeProfileID = nil
            } label: {
                HStack {
                    Text("All profiles")
                    if state.store.activeProfileID == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            if !state.store.profiles.isEmpty {
                Divider()
                ForEach(state.store.profiles) { p in
                    Button {
                        state.store.activeProfileID = p.id
                    } label: {
                        HStack {
                            Text(p.name)
                            if state.store.activeProfileID == p.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Manage profiles…", action: onShowProfiles)
        } label: {
            HStack(spacing: 6) {
                let active = state.store.profiles.first(where: { $0.id == state.store.activeProfileID })
                OtoIcon(name: active?.icon ?? "grid-2x2", size: 12)
                Text(active?.name ?? "All")
                    .font(.system(size: 12, weight: .medium))
                OtoIcon(name: "chevron-down", size: 9)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OtoUI.rowIdle, in: Capsule())
            .foregroundStyle(OtoUI.secondaryFG)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func showOverflowMenu() {
        guard let contentView = NSApp.keyWindow?.contentView else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(title: "Profiles…", systemImage: "person.2", action: onShowProfiles))
        menu.addItem(menuItem(title: "Devices…", systemImage: "cable.connector", action: onShowDevices))
        menu.addItem(menuItem(title: "Settings…", systemImage: "gearshape", action: onShowSettings))
        menu.addItem(menuItem(title: "About", systemImage: "info.circle", action: onShowAbout))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Oto", systemImage: "power", action: {
            NSApplication.shared.terminate(nil)
        }))

        let mouseInScreen = NSEvent.mouseLocation
        guard let window = contentView.window else { return }
        let pointInWindow = NSPoint(
            x: mouseInScreen.x - window.frame.minX,
            y: mouseInScreen.y - window.frame.minY
        )
        let pointInView = contentView.convert(pointInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: contentView)
    }

    private func menuItem(title: String, systemImage: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = OverflowMenuTarget(action)
        let item = NSMenuItem(title: title, action: #selector(OverflowMenuTarget.fire), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        return item
    }
}

private final class OverflowMenuTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}
