import SwiftUI
import AppKit

// MARK: - DevicesSheet

struct DevicesSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.otoDismiss) private var dismiss
    @State private var btMonitor = BluetoothPeripheralMonitor()

    var inputs: [AudioDevice] { state.monitor.allDevices.filter(\.hasInput) }
    var outputs: [AudioDevice] { state.monitor.allDevices.filter(\.hasOutput) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Devices")
                    .font(.system(size: OtoUI.titleSize, weight: .semibold))
                Text("All audio devices currently visible to the system.")
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: "Inputs", count: inputs.count, devices: inputs, isInput: true)
                    section(title: "Outputs", count: outputs.count, devices: outputs, isInput: false)
                    bluetoothSection
                }
                .padding(.bottom, 4)
            }
            .frame(maxHeight: 440)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.otoTeal)
            }
        }
        .padding(26)
        .frame(width: 600)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Bluetooth")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(btMonitor.connectedDevices.count)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(OtoUI.rowIdle, in: Capsule())
                    .foregroundStyle(OtoUI.mutedFG)
            }
            if btMonitor.connectedDevices.isEmpty {
                Text("No Bluetooth devices connected.")
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(btMonitor.connectedDevices) { device in
                        bluetoothDeviceRow(device)
                    }
                }
            }
        }
        .onAppear { btMonitor.refresh() }
    }

    private func bluetoothDeviceRow(_ device: BluetoothPeripheral) -> some View {
        let tint = Color.otoNavy
        return HStack(spacing: 12) {
            OtoIcon(name: device.kind.systemImage, size: 18)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                        .strokeBorder(tint.opacity(0.32), lineWidth: 1)
                }
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 14, weight: .medium))
                Text(device.kind.label)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            Spacer()

            Text("Connected")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.18), in: Capsule())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }

    private func section(title: String, count: Int, devices: [AudioDevice], isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(OtoUI.rowIdle, in: Capsule())
                    .foregroundStyle(OtoUI.mutedFG)
            }
            if devices.isEmpty {
                Text("No devices.")
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(devices) { device in
                        deviceRow(device, isInput: isInput)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: AudioDevice, isInput: Bool) -> some View {
        let direction: DeviceLockManager.Direction = isInput ? .input : .output
        let isCurrent = isInput
            ? device.uid == state.monitor.defaultInputDevice?.uid
            : device.uid == state.monitor.defaultOutputDevice?.uid
        let isLocked = state.deviceLock.isLocked(device, direction: direction)
        let tint = device.displayTint
        return HStack(spacing: 12) {
            OtoIcon(name: device.kind.systemImage, size: 18)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                        .strokeBorder(tint.opacity(0.32), lineWidth: 1)
                }
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .medium))
                    if isLocked {
                        OtoIcon(name: "lock.fill", size: 11)
                            .foregroundStyle(Color.otoTeal)
                            .help(isInput
                                  ? "Locked as default input — Oto will re-pin if macOS changes it."
                                  : "Locked as default output — Oto will re-pin if macOS changes it.")
                            .accessibilityLabel("Locked as default")
                    }
                }
                Text(device.kind.label)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            Spacer()

            // Lock toggle — small icon button. Hidden for input devices that
            // can't be input (and likewise for output) so users can't lock a
            // direction the device doesn't support.
            let canLock = isInput ? device.hasInput : device.hasOutput
            if canLock {
                Button {
                    state.deviceLock.toggleLock(device, direction: direction)
                } label: {
                    OtoIcon(name: isLocked ? "lock.fill" : "lock.open", size: 13)
                        .frame(width: 26, height: 26)
                        .foregroundStyle(isLocked ? Color.otoTeal : OtoUI.mutedFG)
                }
                .buttonStyle(.plain)
                .help(isLocked ? "Unlock — let macOS choose freely" : "Lock as default — Oto re-asserts on every change")
                .accessibilityLabel(isLocked ? "Unlock device" : "Lock as default")
            }

            if isCurrent {
                Text("Active")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.otoTeal.opacity(0.18), in: Capsule())
                    .foregroundStyle(Color.otoTeal)
            } else {
                Button("Make Default") {
                    if isInput {
                        state.switchTo(device)
                    } else {
                        try? AudioDeviceSwitcher.setDefaultOutput(device)
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }
}

// MARK: - AboutSheet

struct AboutSheet: View {
    @Environment(\.otoDismiss) private var dismiss

    /// Pulled from Info.plist so a release-build version bump propagates
    /// without touching this file. Falls back gracefully in the rare case
    /// either key is absent (e.g. running unit-test bundles).
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let b, b != v { return "v\(v) (\(b))" }
        return "v\(v)"
    }

    private static let repoURL = URL(string: "https://github.com/0xadiyat/oto")!

    var body: some View {
        VStack(spacing: 14) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
            Image("LogoWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
            Text(versionString)
                .font(.system(size: 12))
                .foregroundStyle(OtoUI.mutedFG)
            Text("Automatic audio input switching for macOS.")
                .font(.system(size: 13))
                .foregroundStyle(OtoUI.mutedFG)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            // Repo link — `Link` rather than `Button { NSWorkspace.open }`
            // so VoiceOver announces "link" and the user's default browser
            // opens cleanly. Lucide github mark mounted as a template image
            // so it tints to the current foreground colour.
            Link(destination: Self.repoURL) {
                HStack(spacing: 6) {
                    Image("github")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("View on GitHub")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(OtoUI.rowIdle, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1)
                }
                .foregroundStyle(OtoUI.secondaryFG)
            }
            .buttonStyle(.plain)
            .help("github.com/0xadiyat/oto")
            .accessibilityLabel("View Oto on GitHub")
            .padding(.top, 6)

            Spacer(minLength: 0)

            // Standard macOS About-window copyright — same one-line format
            // Apple uses (e.g. "Copyright © 2026 Apple Inc.") so this reads
            // as native to anyone who's seen `About this Mac`.
            Text("Copyright © 2026 0xAdiyat. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(OtoUI.mutedFG.opacity(0.85))
                .multilineTextAlignment(.center)

            Button("Close") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.otoTeal)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .frame(width: 420, height: 400)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }
}
