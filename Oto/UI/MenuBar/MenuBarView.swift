import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let openMain: () -> Void

    private func openMainAndDismiss() {
        dismiss()
        openMain()
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
            IconButton(icon: "gearshape", iconSize: 14, help: "Open Oto") {
                openMainAndDismiss()
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

