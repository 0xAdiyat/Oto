import SwiftUI
import UserNotifications
import AppKit

struct OverviewView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var levelMonitor = InputLevelMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview").font(.largeTitle).bold()
                Text("A snapshot of Oto's current state.")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                statCard(
                    title: "Active Input",
                    value: state.monitor.defaultInputDevice?.name ?? "None",
                    icon: state.monitor.defaultInputDevice?.kind.systemImage ?? "mic-off",
                    tint: state.monitor.defaultInputDevice?.displayTint ?? .secondary,
                    extra: AnyView(LevelBar(level: levelMonitor.level).frame(height: 6).padding(.top, 4))
                )
                statCard(
                    title: "Connected Devices",
                    value: "\(state.monitor.allDevices.count)",
                    icon: "cable",
                    tint: .otoTeal,
                    extra: nil
                )
                statCard(
                    title: "Active Rules",
                    value: "\(state.store.rules.filter(\.enabled).count) of \(state.store.rules.count)",
                    icon: "list-checks",
                    tint: .otoNavy,
                    extra: nil
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recent activity").font(.headline)
                if state.store.fireHistory.isEmpty {
                    Text("No rules have fired yet. Connect or disconnect a device to test your rules.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(state.store.fireHistory.prefix(20)) { event in
                                fireRow(event)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { levelMonitor.start() }
        .onDisappear { levelMonitor.stop() }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color, extra: AnyView?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OtoIcon(name: icon, size: 18)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold().lineLimit(1)
            if let extra { extra }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func fireRow(_ event: RuleFireEvent) -> some View {
        let style = outcomeStyle(event.outcome)
        return HStack(spacing: 12) {
            OtoIcon(name: style.icon, size: 14)
                .frame(width: 28, height: 28)
                .background(style.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(style.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.ruleSummary).font(.callout)
                Text("\(style.prefix) \(event.deviceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.firedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func outcomeStyle(_ outcome: RuleFireOutcome) -> (icon: String, color: Color, prefix: String) {
        switch outcome {
        case .applied: return ("zap", .accentColor, "→")
        case .noOp: return ("circle-pause", .secondary, "—")
        case .targetMissing: return ("triangle-alert", .otoYellow, "Target missing:")
        case .failed: return ("octagon-x", .otoAlert, "Failed:")
        }
    }
}

struct DevicesView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var tester = MicTester()
    @State private var testingDeviceUID: String? = nil

    var inputs: [AudioDevice] { state.monitor.allDevices.filter(\.hasInput) }
    var outputs: [AudioDevice] { state.monitor.allDevices.filter(\.hasOutput) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Devices").font(.largeTitle).bold()
                Text("All audio devices currently visible to the system.")
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "Inputs (\(inputs.count))", devices: inputs, isInput: true)
                    section(title: "Outputs (\(outputs.count))", devices: outputs, isInput: false)
                }
                .padding(.bottom, 24)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func section(title: String, devices: [AudioDevice], isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 8) {
                ForEach(devices) { device in
                    deviceRow(device, isInput: isInput)
                }
                if devices.isEmpty {
                    Text("No devices.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func deviceRow(_ device: AudioDevice, isInput: Bool) -> some View {
        let isCurrentInput = isInput && device.uid == state.monitor.defaultInputDevice?.uid
        return HStack(spacing: 12) {
            OtoIcon(name: device.kind.systemImage, size: 18)
                .frame(width: 36, height: 36)
                .background(device.displayTint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(device.displayTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.callout.weight(.medium))
                Text(device.kind.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isInput {
                // Test mic button (only enabled if it's the current default —
                // AVAudioEngine taps the default input).
                if isCurrentInput {
                    Button {
                        tester.toggleTest()
                        testingDeviceUID = device.uid
                    } label: {
                        switch tester.state {
                        case .idle: Label { Text("Test") } icon: { OtoIcon(name: "audio-waveform", size: 12) }
                        case .recording: Label { Text("Recording…") } icon: { OtoIcon(name: "square", size: 12) }
                        case .playing: Label { Text("Playing…") } icon: { OtoIcon(name: "volume-2", size: 12) }
                        }
                    }
                    .controlSize(.small)
                    .disabled(testingDeviceUID != nil && testingDeviceUID != device.uid && tester.state != .idle)

                    Text("Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                } else {
                    Button("Make Default") { state.switchTo(device) }
                        .controlSize(.small)
                }
            } else {
                Button("Make Default") { try? AudioDeviceSwitcher.setDefaultOutput(device) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @AppStorage("Oto.showNotifications") private var showNotifications = true
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.largeTitle).bold()
            Form {
                Toggle("Launch Oto at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }

                Toggle("Show notifications when input switches", isOn: $showNotifications)
                    .onChange(of: showNotifications) { _, newValue in
                        if newValue {
                            NotificationService.shared.requestAuthorizationIfNeeded()
                            Task { notificationStatus = await NotificationService.shared.authorizationStatus() }
                        }
                    }
                    .disabled(notificationStatus == .denied)

                if notificationStatus == .denied && showNotifications {
                    HStack(spacing: 8) {
                        OtoIcon(name: "triangle-alert", size: 14)
                            .foregroundStyle(Color.otoYellow)
                        Text("Notifications are disabled in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }
            .formStyle(.grouped)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            Task { notificationStatus = await NotificationService.shared.authorizationStatus() }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 96)
            Image("LogoWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
            Text("v1.0.0").foregroundStyle(.secondary)
            Text("Automatic audio input switching for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Text("Tip: install Oto in /Applications and avoid moving it later — login-at-startup tracks the bundle path.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - LevelBar

private struct LevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.otoTeal, .otoYellow, .otoAlert], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, geo.size.width * CGFloat(level)))
            }
        }
    }
}
