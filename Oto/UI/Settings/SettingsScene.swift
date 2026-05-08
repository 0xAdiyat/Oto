import AppKit
import SwiftUI
import UserNotifications

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, automation, devices, quietHours, notifications, hotkey, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .automation: return "Automation"
        case .devices: return "Devices"
        case .quietHours: return "Quiet Hours"
        case .notifications: return "Notifications"
        case .hotkey: return "Hotkey"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .automation: return "wand.and.stars"
        case .devices: return "headphones"
        case .quietHours: return "moon.zzz"
        case .notifications: return "bell"
        case .hotkey: return "command"
        case .about: return "info.circle"
        }
    }
}

struct OtoSettingsView: View {
    @Environment(AppState.self) private var state
    @State private var selected: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            
            Rectangle()
                .fill(OtoSettingsUI.glassStroke)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: OtoSettingsUI.sectionSpacing) {
                    selectedContent
                }
                .padding(.top, OtoSettingsUI.contentTopPadding)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.clear)
        }
        .frame(width: OtoSettingsUI.windowWidth, height: OtoSettingsUI.windowHeight)
        .background(.ultraThinMaterial)
        .background(Color.otoSettingsSurface.opacity(0.96))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [OtoSettingsUI.glassHighlight, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
        .overlay {
            Rectangle()
                .strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: OtoSettingsUI.windowShadow, radius: 34, x: 0, y: 24)
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .background(SettingsWindowConfigurator())
    }

    private var settingsHeader: some View {
        ZStack(alignment: .topLeading) {
            Text("Oto Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OtoSettingsUI.valueFG)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)

            HStack(alignment: .top, spacing: 16) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsTopTab(
                        section: section,
                        isSelected: selected == section
                    ) {
                        selected = section
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 25)
        }
        .frame(height: OtoSettingsUI.topBarHeight)
        .background(Color.otoSettingsSurface.opacity(0.42))
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selected {
        case .general:
            GeneralSettingsContent()
        case .automation:
            AutomationSettingsContent()
        case .devices:
            DeviceSettingsContent()
        case .quietHours:
            QuietHoursSettingsContent()
        case .notifications:
            NotificationsSettingsContent()
        case .hotkey:
            HotkeySettingsContent()
        case .about:
            AboutSettingsContent()
        }
    }
}

private struct SettingsTopTab: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                OtoIcon(name: section.icon, size: 15)
                    .foregroundStyle(isSelected ? OtoSettingsUI.valueFG : OtoSettingsUI.quietFG)
                    .frame(height: 18)
                Text(section.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: OtoSettingsUI.topTabWidth, height: OtoSettingsUI.topTabHeight)
            .background(rowFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
            .foregroundStyle(isSelected ? OtoSettingsUI.valueFG : OtoSettingsUI.quietFG)
            .contentShape(RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous)
                        .strokeBorder(OtoSettingsUI.strongStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
        .animation(OtoUI.hoverEase, value: isSelected)
    }

    private var rowFill: Color {
        if isSelected { return OtoSettingsUI.tabSelected }
        return isHovering ? OtoSettingsUI.tabHover : Color.clear
    }
}

// MARK: - General

private struct GeneralSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var currentHotkey: HotkeyShortcut?

    var body: some View {
        VStack(spacing: 0) {
            SettingsContentSection {
                SettingsFieldRow(label: "Startup") {
                    Toggle("Launch Oto at login", isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLogin.setEnabled(newValue)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                }

                SettingsFieldRow(label: "Oto Hotkey") {
                    HotkeyRecorder(shortcut: $currentHotkey) { new in
                        GlobalHotkeyManager.shared.update(new)
                        currentHotkey = GlobalHotkeyManager.shared.shortcut
                    }
                    .frame(width: 300)
                }
            }

            SettingsContentSection {
                SettingsFieldRow(label: "Setup") {
                    Button {
                        NSApp.keyWindow?.close()
                        SpotlightWindowController.shared.present(activate: true)
                        state.presentFirstRunSetup()
                    } label: {
                        HStack {
                            Text("Run first-run setup")
                            Spacer()
                            OtoIcon(name: "arrow.up.right", size: 12)
                        }
                        .padding(.horizontal, 14)
                        .frame(width: 300, height: 34)
                        .background(OtoSettingsUI.controlFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            currentHotkey = GlobalHotkeyManager.shared.shortcut
        }
    }
}

// MARK: - Automation

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all, applied, skipped, missing, failed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .applied: return "Applied"
        case .skipped: return "Skipped"
        case .missing: return "Missing Target"
        case .failed: return "Failed"
        }
    }
}

private struct AutomationSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var filter: ActivityFilter = .all
    @State private var showClearConfirmation = false

    private var filteredEvents: [RuleFireEvent] {
        state.store.fireHistory.filter { event in
            switch filter {
            case .all: return true
            case .applied: return event.outcome == .applied
            case .skipped: return event.outcome == .noOp
            case .missing: return event.outcome == .targetMissing
            case .failed: return event.outcome == .failed
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsContentSection {
                SettingsFieldRow(label: "Activity") {
                    HStack(spacing: 10) {
                        Text("\(state.store.fireHistory.count) recent events")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OtoSettingsUI.quietFG)
                        Spacer()
                        Button("Clear Activity") {
                            showClearConfirmation = true
                        }
                        .controlSize(.small)
                        .disabled(state.store.fireHistory.isEmpty)
                    }
                    .frame(width: 300)
                }

                SettingsFieldRow(label: "Filter") {
                    Picker("", selection: $filter) {
                        ForEach(ActivityFilter.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 300)
                }
            }

            SettingsContentSection(verticalPadding: 18) {
                RuleActivityTimeline(events: filteredEvents)
                    .frame(width: OtoSettingsUI.contentMaxWidth)
                    .frame(minHeight: 260)
                    .background(OtoSettingsUI.subtleFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
            }
        }
        .confirmationDialog("Clear activity?", isPresented: $showClearConfirmation) {
            Button("Clear Activity", role: .destructive) {
                state.store.clearFireHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local rule timeline entries. Your rules are not changed.")
        }
    }
}

private struct RuleActivityTimeline: View {
    let events: [RuleFireEvent]

    var body: some View {
        if events.isEmpty {
            VStack(spacing: 8) {
                OtoIcon(name: "clock", size: 22)
                    .foregroundStyle(OtoSettingsUI.quietFG)
                Text("No activity yet")
                    .font(.system(size: OtoUI.metaSize, weight: .semibold))
                Text("Rule runs and dry-run checks will appear here.")
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            VStack(spacing: 0) {
                ForEach(events) { event in
                    ActivityEventRow(event: event)
                    if event.id != events.last?.id {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
        }
    }
}

private struct ActivityEventRow: View {
    let event: RuleFireEvent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(outcomeTint.opacity(0.18))
                OtoIcon(name: iconName, size: 14, weight: .medium)
                    .foregroundStyle(outcomeTint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(event.isDryRun ? "Dry run" : event.ruleSummary)
                        .font(.system(size: OtoUI.metaSize, weight: .semibold))
                    OutcomeBadge(outcome: event.outcome, isDryRun: event.isDryRun)
                    Spacer(minLength: 0)
                    Text(event.firedAt, style: .time)
                        .font(.system(size: OtoUI.captionSize))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                }

                Text(event.actionSummary ?? event.deviceName)
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.valueFG)

                if let result = event.resultSummary {
                    Text(result)
                        .font(.system(size: OtoUI.captionSize))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                }

                HStack(spacing: 6) {
                    if let profile = event.profileName {
                        miniMeta("Profile: \(profile)")
                    }
                    if let condition = event.conditionSummary {
                        miniMeta(condition)
                    }
                }
            }
        }
        .padding(16)
    }

    private var outcomeTint: Color {
        switch event.outcome {
        case .applied: return Color.otoTeal
        case .noOp: return Color.otoYellow
        case .targetMissing, .failed: return Color.otoAlert
        }
    }

    private var iconName: String {
        switch event.outcome {
        case .applied: return "checkmark"
        case .noOp: return "pause"
        case .targetMissing: return "questionmark"
        case .failed: return "xmark"
        }
    }

    private func miniMeta(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(OtoSettingsUI.controlFill, in: Capsule())
            .foregroundStyle(OtoSettingsUI.quietFG)
    }
}

private struct OutcomeBadge: View {
    let outcome: RuleFireOutcome
    let isDryRun: Bool

    var body: some View {
        Text(isDryRun ? "Dry Run" : outcome.displayText)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        if isDryRun { return Color.otoNavy }
        switch outcome {
        case .applied: return Color.otoTeal
        case .noOp: return Color.otoYellow
        case .targetMissing, .failed: return Color.otoAlert
        }
    }
}

// MARK: - Devices

private struct DeviceSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            SettingsContentSection {
                deviceSection(title: "Inputs", devices: state.monitor.allDevices.filter(\.hasInput), isInput: true)
            }
            SettingsContentSection {
                deviceSection(title: "Outputs", devices: state.monitor.allDevices.filter(\.hasOutput), isInput: false)
            }
        }
    }

    private func deviceSection(title: String, devices: [AudioDevice], isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                Text("\(devices.count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(OtoSettingsUI.controlFill, in: Capsule())
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }

            if devices.isEmpty {
                Text("No devices visible to macOS.")
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.quietFG)
            } else {
                VStack(spacing: 8) {
                    ForEach(devices) { device in
                        settingsDeviceRow(device, isInput: isInput)
                    }
                }
            }
        }
        .frame(width: OtoSettingsUI.contentMaxWidth, alignment: .leading)
    }

    private func settingsDeviceRow(_ device: AudioDevice, isInput: Bool) -> some View {
        let direction: DeviceLockManager.Direction = isInput ? .input : .output
        let isCurrent = isInput ? device.uid == state.monitor.defaultInputDevice?.uid : device.uid == state.monitor.defaultOutputDevice?.uid
        let isLocked = state.deviceLock.isLocked(device, direction: direction)
        return HStack(spacing: 12) {
            OtoIcon(name: device.kind.systemImage, size: 16)
                .frame(width: 30, height: 30)
                .background(device.displayTint.opacity(0.14), in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous))
                .foregroundStyle(device.displayTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: OtoUI.metaSize, weight: .medium))
                Text(device.kind.label)
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }

            Spacer()

            Button {
                state.deviceLock.toggleLock(device, direction: direction)
            } label: {
                OtoIcon(name: isLocked ? "lock.fill" : "lock.open", size: 13)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isLocked ? Color.otoTeal : OtoSettingsUI.quietFG)
            .help(isLocked ? "Unlock default device" : "Lock as default device")

            if isCurrent {
                Text("Active")
                    .font(.system(size: 10, weight: .bold))
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
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(OtoSettingsUI.subtleFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
    }
}

// MARK: - Quiet Hours

private struct QuietHoursSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var quietHours = state.quietHours
        VStack(spacing: 0) {
            SettingsContentSection {
                SettingsFieldRow(label: "Mode") {
                    Toggle("Limit output volume", isOn: $quietHours.settings.enabled)
                        .toggleStyle(.checkbox)
                }

                SettingsFieldRow(label: "From") {
                    TimePickerRow(label: "", minutes: $quietHours.settings.startMinute)
                        .frame(width: 300)
                        .disabled(!quietHours.settings.enabled)
                }

                SettingsFieldRow(label: "To") {
                    TimePickerRow(label: "", minutes: $quietHours.settings.endMinute)
                        .frame(width: 300)
                        .disabled(!quietHours.settings.enabled)
                }
            }

            SettingsContentSection {
                SettingsFieldRow(label: "Max Volume") {
                    HStack(spacing: 12) {
                        Text("\(Int(quietHours.settings.maxVolume * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 42, alignment: .leading)
                            .foregroundStyle(OtoSettingsUI.valueFG)
                        Slider(value: $quietHours.settings.maxVolume, in: 0.05...1.0, step: 0.05)
                    }
                    .frame(width: 300)
                    .disabled(!quietHours.settings.enabled)
                }

                SettingsFieldRow(label: "Behavior") {
                    Text("Attempts above the cap reset automatically.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                        .frame(width: 300, alignment: .leading)
                }
            }
        }
    }
}

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
        .datePickerStyle(.compact)
    }

    private static func dateFromMinutes(_ minutes: Int) -> Date {
        let safe = max(0, min(1439, minutes))
        return Calendar.current.date(
            bySettingHour: safe / 60,
            minute: safe % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minutesFromDate(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
// MARK: - Notifications

private struct NotificationsSettingsContent: View {
    @AppStorage("Oto.showNotifications") private var showNotifications = true
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: 0) {
            SettingsContentSection {
                SettingsFieldRow(label: "Rule Events") {
                    Toggle("Notify when rules apply", isOn: $showNotifications)
                        .toggleStyle(.checkbox)
                        .disabled(status == .denied)
                        .onChange(of: showNotifications) { _, newValue in
                            guard newValue else { return }
                            NotificationService.shared.requestAuthorizationIfNeeded()
                            Task { status = await NotificationService.shared.authorizationStatus() }
                        }
                }

                SettingsFieldRow(label: "Status") {
                    Text(notificationSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(status == .denied ? Color.otoYellow : OtoSettingsUI.quietFG)
                        .frame(width: 300, alignment: .leading)
                }
            }

            if status == .denied {
                SettingsContentSection {
                    SettingsFieldRow(label: "Permission") {
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                        .frame(width: 300, alignment: .leading)
                    }
                }
            }
        }
        .onAppear {
            Task { status = await NotificationService.shared.authorizationStatus() }
        }
    }

    private var notificationSubtitle: String {
        status == .denied
            ? "Notifications are disabled in System Settings."
            : "Show a small banner when Oto applies a rule."
    }
}

// MARK: - Hotkey

private struct HotkeySettingsContent: View {
    @State private var current: HotkeyShortcut?

    var body: some View {
        SettingsContentSection {
            SettingsFieldRow(label: "Open Oto") {
                HotkeyRecorder(shortcut: $current) { new in
                    GlobalHotkeyManager.shared.update(new)
                    current = GlobalHotkeyManager.shared.shortcut
                }
                .frame(width: 300)
            }

            SettingsFieldRow(label: "Behavior") {
                Text("Summon the Spotlight panel from anywhere.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .frame(width: 300, alignment: .leading)
            }
        }
        .onAppear { current = GlobalHotkeyManager.shared.shortcut }
    }
}

// MARK: - About

private struct AboutSettingsContent: View {
    private static let repoURL = URL(string: "https://github.com/0xadiyat/oto")!

    var body: some View {
        SettingsContentSection {
            SettingsFieldRow(label: "Version") {
                HStack(spacing: 14) {
                    Image("LogoMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Image("LogoWordmark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                        Text(versionString)
                            .font(.system(size: OtoUI.captionSize))
                            .foregroundStyle(OtoSettingsUI.quietFG)
                    }
                    Spacer()
                }
                .frame(width: 300)
            }

            SettingsFieldRow(label: "Source") {
                Link(destination: Self.repoURL) {
                    HStack {
                        Text("View Oto on GitHub")
                        Spacer()
                        OtoIcon(name: "arrow.up.right", size: 12)
                    }
                    .padding(.horizontal, 14)
                    .frame(width: 300, height: 34)
                    .background(OtoSettingsUI.controlFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(OtoSettingsUI.valueFG)
            }

            SettingsFieldRow(label: "Copyright") {
                Text("Copyright © 2026 0xAdiyat.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .frame(width: 300, alignment: .leading)
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, build != version { return "v\(version) (\(build))" }
        return "v\(version)"
    }
}

// MARK: - Shared Settings Components

private struct SettingsContentSection<Content: View>: View {
    var verticalPadding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                content
            }
                .frame(maxWidth: OtoSettingsUI.contentMaxWidth, alignment: .leading)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(OtoSettingsUI.glassStroke)
                .frame(height: 1)
        }
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OtoSettingsUI.labelFG)
                .frame(width: 118, alignment: .trailing)

            content
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OtoSettingsUI.valueFG)
                .frame(width: 300, alignment: .leading)
                .frame(minHeight: 36)
        }
        .frame(width: OtoSettingsUI.contentMaxWidth, alignment: .leading)
    }
}

private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = OtoSettingsUI.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            .background(OtoSettingsUI.cardFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                    .strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [OtoSettingsUI.glassHighlight, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 38)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowIcon(name: icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: OtoUI.metaSize, weight: .medium))
                Text(subtitle)
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowIcon(name: icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: OtoUI.metaSize, weight: .medium))
                Text(subtitle)
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .controlSize(.small)
        }
    }
}

private struct SettingsRowIcon: View {
    let name: String

    var body: some View {
        OtoIcon(name: name, size: 16)
            .frame(width: 34, height: 34)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous))
            .background(OtoSettingsUI.controlFill, in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous)
                    .strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
            }
            .foregroundStyle(OtoSettingsUI.valueFG)
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(from: nsView)
    }

    private func configure(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
    }
}
