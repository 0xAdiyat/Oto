import SwiftUI
import UserNotifications
import AppKit

// MARK: - DevicesSheet

struct DevicesSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

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
        let isCurrentInput = isInput && device.uid == state.monitor.defaultInputDevice?.uid
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
                Text(device.name)
                    .font(.system(size: 14, weight: .medium))
                Text(device.kind.label)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            Spacer()

            if isInput {
                if isCurrentInput {
                    Text("Active")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.otoTeal.opacity(0.18), in: Capsule())
                        .foregroundStyle(Color.otoTeal)
                } else {
                    Button("Make Default") { state.switchTo(device) }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                }
            } else {
                Button("Make Default") { try? AudioDeviceSwitcher.setDefaultOutput(device) }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }
}

// MARK: - SettingsSheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @AppStorage("Oto.showNotifications") private var showNotifications = true
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: OtoUI.titleSize, weight: .semibold))

            VStack(spacing: 0) {
                FormRow(label: "Launch") {
                    Toggle("Launch Oto at login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(.otoTeal)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLogin.setEnabled(newValue)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                }

                FormRow(label: "Notify", isLast: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Notify when input switches", isOn: $showNotifications)
                            .toggleStyle(.switch)
                            .tint(.otoTeal)
                            .onChange(of: showNotifications) { _, newValue in
                                if newValue {
                                    NotificationService.shared.requestAuthorizationIfNeeded()
                                    Task { notificationStatus = await NotificationService.shared.authorizationStatus() }
                                }
                            }
                            .disabled(notificationStatus == .denied)

                        if notificationStatus == .denied && showNotifications {
                            HStack(spacing: 8) {
                                OtoIcon(name: "exclamationmark.triangle", size: 13)
                                    .foregroundStyle(Color.otoYellow)
                                Text("Notifications are disabled in System Settings.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(OtoUI.mutedFG)
                                Button("Open Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .controlSize(.mini)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.otoTeal)
            }
        }
        .padding(26)
        .frame(width: 480)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            Task { notificationStatus = await NotificationService.shared.authorizationStatus() }
        }
    }
}

// MARK: - AboutSheet

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

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
            Text("v1.0.0")
                .font(.system(size: 12))
                .foregroundStyle(OtoUI.mutedFG)
            Text("Automatic audio input switching for macOS.")
                .font(.system(size: 13))
                .foregroundStyle(OtoUI.mutedFG)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Text("Tip: install Oto in /Applications and avoid moving it later — login-at-startup tracks the bundle path.")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 14)

            Button("Close") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.otoTeal)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .frame(width: 420, height: 360)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }
}
