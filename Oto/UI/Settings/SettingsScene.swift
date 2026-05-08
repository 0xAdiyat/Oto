import SwiftUI
import UserNotifications
import AppKit

/// Root for the macOS Settings scene (⌘,). Replaces the old in-spotlight
/// `SettingsSheet` with a proper `Settings` window so Oto plays by macOS
/// conventions — discoverable through the App menu, opened via `openSettings`,
/// surfaced in System Settings → Login Items, etc.
struct OtoSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            HotkeySettingsTab()
                .tabItem { Label("Hotkey", systemImage: "command") }

            QuietHoursSettingsTab()
                .tabItem { Label("Quiet Hours", systemImage: "moon.zzz") }

            NotificationsSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .scenePadding()
        .frame(width: 520, height: 420)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Toggle("Launch Oto at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    // Re-read in case the system rejected the request
                    // (sandboxing, lack of permission, etc.). This avoids
                    // the toggle silently disagreeing with reality.
                    launchAtLogin = LaunchAtLogin.isEnabled
                }

            Text("Oto will start automatically when you log in to your Mac and stay in the menu bar.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: - Hotkey

private struct HotkeySettingsTab: View {
    @State private var current: HotkeyShortcut?

    var body: some View {
        Form {
            Section {
                LabeledContent("Open Oto") {
                    HotkeyRecorder(shortcut: $current) { new in
                        GlobalHotkeyManager.shared.update(new)
                        // Re-read the manager — registration can fail and
                        // the manager will null it out, in which case the
                        // recorder should reflect the actual state.
                        current = GlobalHotkeyManager.shared.shortcut
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional. When set, this combo summons the Oto panel from anywhere — even when another app is fullscreen.")
                    Text("Tip: tap **Delete** while recording to clear, or **Escape** to cancel.")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear { current = GlobalHotkeyManager.shared.shortcut }
    }
}

// MARK: - Quiet Hours

private struct QuietHoursSettingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var bindable = state.quietHours
        Form {
            Section {
                Toggle("Limit output volume during quiet hours", isOn: $bindable.settings.enabled)
            } footer: {
                Text("Caps your Mac's output volume between the times below. Useful as a late-night safety net so you don't accidentally blast music when reaching for your headphones.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Schedule") {
                TimePickerRow(label: "From", minutes: $bindable.settings.startMinute)
                TimePickerRow(label: "To",   minutes: $bindable.settings.endMinute)
                if bindable.settings.startMinute == bindable.settings.endMinute {
                    Label("Start and end can't be the same — pick a window.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.otoYellow)
                } else if windowWraps {
                    Text("This window wraps midnight — e.g. \(prettyTime(bindable.settings.startMinute)) tonight to \(prettyTime(bindable.settings.endMinute)) tomorrow.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!bindable.settings.enabled)

            Section("Maximum volume") {
                HStack {
                    Slider(value: $bindable.settings.maxVolume, in: 0.05...1.0, step: 0.05)
                    Text("\(Int(bindable.settings.maxVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!bindable.settings.enabled)
        }
        .formStyle(.grouped)
    }

    private var windowWraps: Bool {
        state.quietHours.settings.startMinute > state.quietHours.settings.endMinute
    }

    private func prettyTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let comps = DateComponents(hour: h, minute: m)
        let cal = Calendar.current
        guard let date = cal.date(from: comps) else { return "\(h):\(m)" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

/// Compact time picker that round-trips through "minutes since midnight".
/// We can't bind a `DatePicker` directly to an Int, so this wrapper does
/// the conversion in both directions.
private struct TimePickerRow: View {
    let label: String
    @Binding var minutes: Int

    var body: some View {
        DatePicker(
            label,
            selection: Binding(
                get: { Self.dateFromMinutes(minutes) },
                set: { minutes = Self.minutesFromDate($0) }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private static func dateFromMinutes(_ m: Int) -> Date {
        let safe = max(0, min(1439, m))
        var comps = DateComponents()
        comps.hour = safe / 60
        comps.minute = safe % 60
        // Anchor to today so DatePicker has a well-defined date — only
        // hour/minute are surfaced via `displayedComponents`.
        return Calendar.current.date(bySettingHour: comps.hour ?? 0,
                                     minute: comps.minute ?? 0,
                                     second: 0,
                                     of: Date()) ?? Date()
    }

    private static func minutesFromDate(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}

// MARK: - Notifications

private struct NotificationsSettingsTab: View {
    @AppStorage("Oto.showNotifications") private var showNotifications = true
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                Toggle("Notify when input switches", isOn: $showNotifications)
                    .disabled(status == .denied)
                    .onChange(of: showNotifications) { _, newValue in
                        guard newValue else { return }
                        NotificationService.shared.requestAuthorizationIfNeeded()
                        Task { status = await NotificationService.shared.authorizationStatus() }
                    }
            } footer: {
                Group {
                    if status == .denied {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.otoYellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications are disabled in System Settings.")
                                Button("Open System Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .controlSize(.small)
                            }
                        }
                    } else {
                        Text("A small banner appears whenever a rule fires, showing which device Oto switched to.")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            Task { status = await NotificationService.shared.authorizationStatus() }
        }
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    private static let repoURL = URL(string: "https://github.com/0xadiyat/oto")!

    var body: some View {
        VStack(spacing: 14) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(height: 72)
            Image("LogoWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
            Text(versionString)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Automatic audio input switching for macOS.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Same "View on GitHub" affordance as the modal AboutSheet so
            // the two surfaces feel identical to a user. Using SwiftUI
            // `Link` here too — opens the user's default browser, gets
            // a "link" trait in VoiceOver, and on macOS 14+ matches the
            // platform pointer-conversion idiom for hyperlinks.
            Link(destination: Self.repoURL) {
                HStack(spacing: 6) {
                    Image("github")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                    Text("View on GitHub")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help("github.com/0xadiyat/oto")
            .accessibilityLabel("View Oto on GitHub")

            Spacer(minLength: 0)

            Text("Copyright © 2026 0xAdiyat. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let b, b != v { return "v\(v) (\(b))" }
        return "v\(v)"
    }
}
