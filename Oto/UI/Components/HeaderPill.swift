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
        HStack(spacing: 10) {
            Image("LogoFull")
                .resizable()
                .scaledToFit()
                .frame(height: 20)

            Text("Rules")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OtoUI.primaryFG)

            Spacer()

            profilePicker

            MasterToggle()

            HStack(spacing: 2) {
                HeaderIconButton(icon: "plus", help: "Add rule", action: onAdd)
                HeaderIconButton(icon: "wand.and.stars", help: "Templates", action: onTemplates)
                HeaderIconButton(icon: "ellipsis", help: "More", action: showOverflowMenu)
            }
            .opacity(isHovering ? 1 : 0.85)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
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
            HStack(spacing: 5) {
                let active = state.store.profiles.first(where: { $0.id == state.store.activeProfileID })
                OtoIcon(name: active?.icon ?? "square.grid.2x2", size: 11)
                Text(active?.name ?? "All")
                    .font(.system(size: 11, weight: .medium))
                OtoIcon(name: "chevron.down", size: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(OtoUI.rowIdle, in: Capsule())
            .foregroundStyle(OtoUI.secondaryFG)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .focusEffectDisabled()
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

// MARK: - MasterToggle

/// Compound status pill + master pause/resume button. Replaces the static
/// "● Active" label that used to sit here.
///
/// Three derived states from the rule list — captured once in `summary` so
/// the body, tooltip, accessibility, and animation keys all see the same
/// truth on every render:
///
///   • allActive  — every rule enabled (typical happy-path)
///   • paused     — every rule disabled (user hit pause-all)
///   • mixed      — some rules enabled, some not (only with profile-scoped
///                   rules + per-rule toggles)
///   • idle       — no rules at all (greyed out, click is a no-op)
///
/// Click semantics match the FilterTabsBar second-click behaviour, so users
/// who learn either gesture get the same vocabulary in both places:
///   • from any state with at least one enabled rule → pause all
///   • from `paused`                                 → resume all
///   • from `idle`                                   → no action
private struct MasterToggle: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let summary = Summary(rules: state.store.rules)

        Button {
            performToggle(summary: summary)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(summary.dotColor)
                    .frame(width: 6, height: 6)
                Text(summary.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(summary.fgColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(OtoUI.rowIdle, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(summary.borderColor, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(summary.kind == .idle)
        .help(summary.helpText)
        .accessibilityLabel("Master rule toggle")
        .accessibilityValue(summary.accessibilityValue)
        .accessibilityHint("Click to \(summary.actionVerb) all rules")
        .contextMenu {
            Button("Pause all rules") { state.store.setAllRulesEnabled(false) }
                .disabled(!summary.hasAnyEnabled)
            Button("Resume all rules") { state.store.setAllRulesEnabled(true) }
                .disabled(!summary.hasAnyDisabled)
        }
        .animation(.easeOut(duration: 0.14), value: summary.kind)
    }

    private func performToggle(summary: Summary) {
        switch summary.kind {
        case .idle: return
        case .paused: state.store.setAllRulesEnabled(true)
        case .allActive, .mixed: state.store.setAllRulesEnabled(false)
        }
    }
}

/// Pure value type computed from a rule list. All visual / a11y state lives
/// here so the SwiftUI body stays declarative and the same Summary instance
/// is reused for every read in a single render pass.
private struct Summary: Equatable {
    enum Kind: Equatable { case allActive, paused, mixed, idle }

    let kind: Kind
    let activeCount: Int
    let totalCount: Int

    init(rules: [Rule]) {
        totalCount = rules.count
        activeCount = rules.lazy.filter(\.enabled).count
        if totalCount == 0 {
            kind = .idle
        } else if activeCount == 0 {
            kind = .paused
        } else if activeCount == totalCount {
            kind = .allActive
        } else {
            kind = .mixed
        }
    }

    var label: String {
        switch kind {
        case .allActive: return "Active"
        case .paused:    return "Paused"
        case .mixed:     return "\(activeCount)/\(totalCount)"
        case .idle:      return "No rules"
        }
    }

    var dotColor: Color {
        switch kind {
        case .allActive: return .otoTeal
        case .paused:    return .otoAlert
        case .mixed:     return .otoYellow
        case .idle:      return OtoUI.mutedFG
        }
    }

    var fgColor: Color {
        kind == .idle ? OtoUI.mutedFG : OtoUI.secondaryFG
    }

    var borderColor: Color {
        switch kind {
        case .allActive: return Color.otoTeal.opacity(0.32)
        case .paused:    return Color.otoAlert.opacity(0.32)
        case .mixed:     return Color.otoYellow.opacity(0.32)
        case .idle:      return Color.clear
        }
    }

    var helpText: String {
        switch kind {
        case .allActive: return "All \(totalCount) rules active — click to pause everything"
        case .paused:    return "All \(totalCount) rules paused — click to resume everything"
        case .mixed:     return "\(activeCount) of \(totalCount) rules active — click to pause everything"
        case .idle:      return "No rules yet"
        }
    }

    var accessibilityValue: String {
        switch kind {
        case .allActive: return "All \(totalCount) rules active"
        case .paused:    return "All \(totalCount) rules paused"
        case .mixed:     return "\(activeCount) of \(totalCount) rules active"
        case .idle:      return "No rules"
        }
    }

    var actionVerb: String {
        switch kind {
        case .paused: return "resume"
        default:       return "pause"
        }
    }

    var hasAnyEnabled:  Bool { activeCount > 0 }
    var hasAnyDisabled: Bool { totalCount - activeCount > 0 && totalCount > 0 }
}

#if DEBUG
#Preview("Header pill — populated") {
    HeaderPill(
        onAdd: {},
        onTemplates: {},
        onShowProfiles: {},
        onShowDevices: {},
        onShowSettings: {},
        onShowAbout: {}
    )
    .environment(AppState.previewPopulated)
    .padding(40)
    .background(Color.black.opacity(0.92))
    .preferredColorScheme(.dark)
}

#Preview("Header pill — empty") {
    HeaderPill(
        onAdd: {},
        onTemplates: {},
        onShowProfiles: {},
        onShowDevices: {},
        onShowSettings: {},
        onShowAbout: {}
    )
    .environment(AppState.previewEmpty)
    .padding(40)
    .background(Color.black.opacity(0.92))
    .preferredColorScheme(.dark)
}
#endif
