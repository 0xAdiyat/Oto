import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    let openMain: () -> Void

    private func openMainAndDismiss() {
        dismiss()
        openMain()
    }

    private func openSettingsAndDismiss() {
        dismiss()
        DispatchQueue.main.async {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            if !state.store.profiles.isEmpty {
                divider
                profileSection
            }

            divider
            currentInputSection

            divider
            connectedInputsSection

            divider
            footer
        }
        .padding(14)
        .frame(width: 340)
        .focusEffectDisabled()
    }

    private var divider: some View {
        Rectangle()
            .fill(OtoUI.dividerColor)
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
            Text("Oto")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Color.otoTeal).frame(width: 7, height: 7)
                Text("Active")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.secondaryFG)
            }
            QuietHoursMenuBarToggle()
            IconButton(icon: "gearshape", iconSize: 14, help: "Settings") {
                openSettingsAndDismiss()
            }
        }
    }

    private var profileSection: some View {
        HStack(spacing: 8) {
            Text("Profile")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG)
            Spacer()
            Menu {
                Button {
                    state.store.activeProfileID = nil
                } label: {
                    Text("All rules active")
                }
                Divider()
                ForEach(state.store.profiles) { p in
                    Button {
                        state.store.activeProfileID = p.id
                    } label: {
                        Text(p.name)
                    }
                }
            } label: {
                let active = state.store.profiles.first(where: { $0.id == state.store.activeProfileID })
                HStack(spacing: 4) {
                    Text(active?.name ?? "All")
                        .font(.system(size: 11, weight: .medium))
                    OtoIcon(name: "chevron.down", size: 9)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(OtoUI.rowIdle, in: Capsule())
                .foregroundStyle(OtoUI.secondaryFG)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var currentInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Input")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG)
            if let current = state.monitor.defaultInputDevice {
                DeviceRow(device: current) {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.otoTeal.opacity(0.18), in: Capsule())
                        .foregroundStyle(Color.otoTeal)
                }
            } else {
                Text("No input device")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
            }
        }
    }

    private var connectedInputsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connected Inputs")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG)

            if otherInputs.isEmpty {
                Text("No other inputs connected.")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
                    .padding(.vertical, 4)
            } else {
                ForEach(otherInputs) { device in
                    DeviceRow(device: device) {
                        Button {
                            state.switchTo(device)
                        } label: {
                            Text("Switch")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(OtoUI.rowIdle, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1)
                                }
                                .foregroundStyle(OtoUI.secondaryFG)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var otherInputs: [AudioDevice] {
        let currentUID = state.monitor.defaultInputDevice?.uid
        return state.inputDevices.filter { $0.uid != currentUID }
    }

    private var footer: some View {
        VStack(spacing: 2) {
            footerButton(icon: "arrow.up.right.square", title: "Open Oto", trailing: nil, action: openMainAndDismiss)
            footerButton(icon: "power", title: "Quit Oto", trailing: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private func footerButton(icon: String, title: String, trailing: String?, action: @escaping () -> Void) -> some View {
        FooterButton(icon: icon, title: title, trailing: trailing, action: action)
    }
}

private struct FooterButton: View {
    let icon: String
    let title: String
    let trailing: String?
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                OtoIcon(name: icon, size: 13)
                    .foregroundStyle(OtoUI.secondaryFG)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11))
                        .foregroundStyle(OtoUI.mutedFG)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: OtoUI.buttonRadius)
                    .fill(isHovering ? OtoUI.rowHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }
}

// MARK: - QuietHoursMenuBarToggle

/// Compact icon-only Quiet Hours control. Sits next to the settings gear so
/// the header stays a row of single-glyph global controls rather than a
/// mixed-metaphor mishmash of pills and gears.
///
/// Three visual states — same vocabulary as the spotlight panel's
/// `QuietHoursStatusChip`, intentionally:
///   • off            → outline icon, muted
///   • scheduled      → solid icon, navy tint (it'll matter later, just not now)
///   • active-now     → solid icon, teal tint + a small dot overlay so the
///                      "the cap is biting *right now*" state is glanceable
///                      without a tooltip
///
/// Single click toggles `enabled`. Right-click opens a context menu with an
/// "Edit schedule…" item that hops to Settings → Quiet Hours, so power
/// users can reschedule without losing their place in the menubar.
private struct QuietHoursMenuBarToggle: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    /// Drives the "active right now?" check. Re-evaluated whenever the
    /// settings struct mutates (covered by @Observable) AND on a 60 s tick
    /// so the icon flips to "active" the moment the window opens, even if
    /// the menubar happens to be open at the boundary.
    @State private var nowTick: Date = .now

    private var settings: QuietHoursSettings { state.quietHours.settings }
    private var isActiveNow: Bool { settings.enabled && settings.isInWindow(now: nowTick) }

    var body: some View {
        Button {
            state.quietHours.settings.enabled.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                // Just the glyph — no capsule, no circle, no fill. State
                // reads from (a) outline-vs-filled SF symbol and (b) tint.
                // Matching the surrounding icon-only header controls (the
                // gear has no container either) keeps the row visually
                // honest as a strip of plain icons.
                OtoIcon(name: iconName, size: 14)
                    .foregroundStyle(iconTint)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())

                // The "biting now" dot — only shows when the cap is in
                // effect this very second. Sized smaller now that there's
                // no background to compete with — pure floating accent.
                if isActiveNow {
                    Circle()
                        .fill(Color.otoTeal)
                        .frame(width: 5, height: 5)
                        .offset(x: 1, y: 1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Click to toggle Quiet Hours. Right-click to edit schedule.")
        .contextMenu {
            Button(settings.enabled ? "Disable Quiet Hours" : "Enable Quiet Hours") {
                state.quietHours.settings.enabled.toggle()
            }
            Divider()
            Button("Edit schedule…") {
                // Dismiss the menubar popover before showing Settings —
                // otherwise the popover stays anchored to the menubar
                // while the Settings window opens behind it on some macOS
                // versions, which feels like nothing happened.
                dismiss()
                openSettings()
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { tick in
            nowTick = tick
        }
        .animation(.easeOut(duration: 0.15), value: settings.enabled)
        .animation(.easeOut(duration: 0.15), value: isActiveNow)
    }

    // MARK: Visual state derivation

    private var iconName: String {
        // SF Symbol "moon.zzz" reads as "quiet/sleep schedule" universally
        // — same icon Apple uses in Focus and Sleep settings. The fill
        // variant carries the "on" state without us needing to draw a
        // separate "off" glyph.
        settings.enabled ? "moon.zzz.fill" : "moon.zzz"
    }

    private var iconTint: Color {
        // Three colour stops, no background/border to lean on:
        //   off          → muted secondary fg (icon visible but recedes)
        //   scheduled    → navy (Oto's "wireless / ambient" colour)
        //   active-now   → teal (Oto's primary "live" accent)
        guard settings.enabled else { return OtoUI.secondaryFG }
        return isActiveNow ? .otoTeal : .otoNavy
    }

    private var helpText: String {
        if !settings.enabled {
            return "Quiet Hours off — click to enable"
        }
        let cap = "\(Int(settings.maxVolume * 100))%"
        let from = formattedTime(settings.startMinute)
        let to   = formattedTime(settings.endMinute)
        if isActiveNow {
            return "Quiet Hours active — output capped at \(cap) until \(to)"
        }
        return "Quiet Hours on — caps output at \(cap) from \(from) to \(to)"
    }

    private var accessibilityLabel: String {
        if !settings.enabled { return "Quiet Hours, off" }
        return isActiveNow ? "Quiet Hours, active right now" : "Quiet Hours, scheduled"
    }

    /// Local-formatter so 24h vs. 12h respects the user's region — the
    /// settings tab does the same thing, this stays consistent.
    private func formattedTime(_ minutes: Int) -> String {
        let safe = max(0, min(1439, minutes))
        var comps = DateComponents()
        comps.hour = safe / 60
        comps.minute = safe % 60
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

private struct DeviceRow<Trailing: View>: View {
    let device: AudioDevice
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let tint = device.displayTint
        return HStack(spacing: 10) {
            OtoIcon(name: device.kind.systemImage, size: 16)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(tint.opacity(0.32), lineWidth: 1)
                }
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(device.kind.label)
                    .font(.system(size: 10))
                    .foregroundStyle(OtoUI.mutedFG)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview("Menu bar — populated") {
    MenuBarView(openMain: {})
        .environment(AppState.previewPopulated)
        .frame(width: 320)
        .preferredColorScheme(.dark)
}

#Preview("Menu bar — empty") {
    MenuBarView(openMain: {})
        .environment(AppState.previewEmpty)
        .frame(width: 320)
        .preferredColorScheme(.dark)
}
#endif
