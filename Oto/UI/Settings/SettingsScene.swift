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

            // Soft hairline: the previous hard 1px rectangle drew an obvious
            // seam between the tab strip and the content area. A 12pt gradient
            // that fades the same hairline colour to clear gives the
            // separation cue without the seam — matches the spotlight panel
            // which never uses hard horizontal rules inside its glass.
            LinearGradient(
                colors: [OtoSettingsUI.glassStroke, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 12)
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .center, spacing: OtoSettingsUI.sectionSpacing) {
                    selectedContent
                    Spacer(minLength: 0)
                }
                .padding(.top, OtoSettingsUI.contentTopPadding)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.clear)
        }
        .frame(width: OtoSettingsUI.windowWidth, height: OtoSettingsUI.windowHeight)
        // Single solid surface, Notion-style. No material stack, no top
        // highlight gradient — the previous compound made the window read
        // as "fancy glass" when the request is "calm dark page".
        .background(Color.otoSettingsSurface)
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
        // Single compact tab strip — the window title bar already announces
        // "Oto Settings", so the duplicate inline title is redundant. Removing
        // it gives the tabs proper vertical breathing room without inflating
        // the toolbar height.
        HStack(spacing: 4) {
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
            VStack(spacing: 6) {
                OtoIcon(name: section.icon, size: 14)
                    .foregroundStyle(iconColor)
                    .frame(height: 16)
                Text(section.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: OtoSettingsUI.topTabWidth, height: OtoSettingsUI.topTabHeight)
            .background(rowFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
            .foregroundStyle(labelColor)
            .contentShape(RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
        .animation(OtoUI.hoverEase, value: isSelected)
    }

    /// Selected tab uses a teal-tinted pill fill — same brand language as the
    /// spotlight panel's "All" filter chip — instead of an outline that read
    /// as a stuck "pressed" state on the previous design.
    private var rowFill: Color {
        if isSelected { return Color.otoTeal.opacity(0.18) }
        return isHovering ? OtoSettingsUI.tabHover : Color.clear
    }

    private var iconColor: Color {
        if isSelected { return Color.otoTeal }
        return OtoSettingsUI.quietFG
    }

    private var labelColor: Color {
        if isSelected { return Color.otoTeal }
        return OtoSettingsUI.quietFG
    }
}

// MARK: - General

private struct GeneralSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var currentHotkey: HotkeyShortcut?

    var body: some View {
        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Startup") {
                SettingsFieldRow(label: "Launch at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLogin.setEnabled(newValue)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                }

                SettingsFieldRow(label: "Hotkey") {
                    HotkeyRecorder(shortcut: $currentHotkey) { new in
                        GlobalHotkeyManager.shared.update(new)
                        currentHotkey = GlobalHotkeyManager.shared.shortcut
                    }
                }
            }

            SettingsContentSection(title: "Onboarding") {
                SettingsFieldRow(label: "First-run setup") {
                    Button {
                        NSApp.keyWindow?.close()
                        SpotlightWindowController.shared.present(activate: true)
                        state.presentFirstRunSetup()
                    } label: {
                        SettingsLinkButtonContent(label: "Run setup again")
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
        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Recent Activity") {
                SettingsFieldRow(label: "Total") {
                    HStack(spacing: 10) {
                        Text("\(state.store.fireHistory.count) events")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(OtoSettingsUI.quietFG)
                        Spacer()
                        Button("Clear") {
                            showClearConfirmation = true
                        }
                        .controlSize(.small)
                        .disabled(state.store.fireHistory.isEmpty)
                    }
                }

                SettingsFieldRow(label: "Filter") {
                    Picker("", selection: $filter) {
                        ForEach(ActivityFilter.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            SettingsContentSection(title: "Timeline", verticalPadding: 0) {
                RuleActivityTimeline(events: filteredEvents)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 260)
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
        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Inputs (\(state.monitor.allDevices.filter(\.hasInput).count))") {
                deviceList(devices: state.monitor.allDevices.filter(\.hasInput), isInput: true)
            }
            SettingsContentSection(title: "Outputs (\(state.monitor.allDevices.filter(\.hasOutput).count))") {
                deviceList(devices: state.monitor.allDevices.filter(\.hasOutput), isInput: false)
            }
        }
    }

    @ViewBuilder
    private func deviceList(devices: [AudioDevice], isInput: Bool) -> some View {
        if devices.isEmpty {
            Text("No devices visible to macOS.")
                .font(.system(size: OtoUI.captionSize))
                .foregroundStyle(OtoSettingsUI.quietFG)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                ForEach(devices) { device in
                    settingsDeviceRow(device, isInput: isInput)
                }
            }
        }
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
        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Schedule") {
                SettingsFieldRow(label: "Limit volume") {
                    Toggle("", isOn: $quietHours.settings.enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsFieldRow(label: "From") {
                    TimePickerRow(label: "", minutes: $quietHours.settings.startMinute)
                        .disabled(!quietHours.settings.enabled)
                }

                SettingsFieldRow(label: "To") {
                    TimePickerRow(label: "", minutes: $quietHours.settings.endMinute)
                        .disabled(!quietHours.settings.enabled)
                }
            }

            SettingsContentSection(
                title: "Volume Cap",
                footnote: "Attempts above the cap reset automatically."
            ) {
                SettingsFieldRow(label: "Max volume") {
                    HStack(spacing: 12) {
                        Slider(value: $quietHours.settings.maxVolume, in: 0.05...1.0, step: 0.05)
                        Text("\(Int(quietHours.settings.maxVolume * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                            .foregroundStyle(OtoSettingsUI.valueFG)
                    }
                    .disabled(!quietHours.settings.enabled)
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
        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(
                title: "Rule Events",
                footnote: "Show a small banner when Oto applies a rule."
            ) {
                SettingsFieldRow(label: "Notify on apply") {
                    Toggle("", isOn: $showNotifications)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(status == .denied)
                        .onChange(of: showNotifications) { _, newValue in
                            guard newValue else { return }
                            NotificationService.shared.requestAuthorizationIfNeeded()
                            Task { status = await NotificationService.shared.authorizationStatus() }
                        }
                }
            }

            if status == .denied {
                SettingsContentSection(
                    title: "Permission",
                    footnote: "Notifications are disabled in System Settings — Oto can't show banners until you enable them."
                ) {
                    SettingsFieldRow(label: "macOS") {
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .onAppear {
            Task { status = await NotificationService.shared.authorizationStatus() }
        }
    }
}

// MARK: - Hotkey

private struct HotkeySettingsContent: View {
    @State private var current: HotkeyShortcut?

    var body: some View {
        SettingsContentSection(
            title: "Global Shortcut",
            footnote: "Summon the spotlight panel from anywhere."
        ) {
            SettingsFieldRow(label: "Open Oto") {
                HotkeyRecorder(shortcut: $current) { new in
                    GlobalHotkeyManager.shared.update(new)
                    current = GlobalHotkeyManager.shared.shortcut
                }
            }
        }
        .onAppear { current = GlobalHotkeyManager.shared.shortcut }
    }
}

// MARK: - About

private struct AboutSettingsContent: View {
    private static let repoURL = URL(string: "https://github.com/0xadiyat/oto")!

    var body: some View {
        SettingsContentSection(
            title: "About Oto",
            footnote: "Copyright © 2026 0xAdiyat."
        ) {
            SettingsFieldRow(label: "Version") {
                HStack(spacing: 12) {
                    Image("LogoMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Image("LogoWordmark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                        Text(versionString)
                            .font(.system(size: OtoUI.captionSize))
                            .foregroundStyle(OtoSettingsUI.quietFG)
                    }
                    Spacer()
                }
            }

            SettingsFieldRow(label: "Source") {
                Link(destination: Self.repoURL) {
                    SettingsLinkButtonContent(label: "View Oto on GitHub")
                }
                .buttonStyle(.plain)
                .foregroundStyle(OtoSettingsUI.valueFG)
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

/// Grouped settings card with an optional small uppercase header.
///
/// Notion-style flat aesthetic: one solid surface that's barely a shade
/// lighter than the page, a single hairline border, nothing else. No
/// material, no tint, no top-highlight gradient, no drop shadow. The
/// visual hierarchy comes from the section title above and the footnote
/// below — typography carries the structure, not chrome.
///
/// `footnote` renders below the card as small muted text — the right
/// place for non-actionable descriptions like "Attempts above the cap
/// reset automatically".
private struct SettingsContentSection<Content: View>: View {
    var title: String? = nil
    var footnote: String? = nil
    var verticalPadding: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .padding(.leading, 4)
            }

            let shape = RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
            VStack(spacing: 4) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 14)
            .background(OtoSettingsUI.cardFill, in: shape)
            .overlay {
                shape.strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: OtoSettingsUI.contentMaxWidth)
    }
}

/// Full-width pill-button content used by link/action rows (Run setup again,
/// View Oto on GitHub). Renders the label + a trailing "↗" affordance, with
/// a hover state so the row feels live instead of like a static label. The
/// caller wraps it in a Button/Link with `.buttonStyle(.plain)` so its own
/// click area covers the whole pill.
private struct SettingsLinkButtonContent: View {
    let label: String
    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            OtoIcon(name: "arrow.up.right", size: 11)
                .foregroundStyle(OtoSettingsUI.quietFG)
                .opacity(isHovering ? 1 : 0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(
            isHovering ? OtoSettingsUI.tabHover : OtoSettingsUI.controlFill,
            in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous)
        )
        .foregroundStyle(OtoSettingsUI.valueFG)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(OtoSettingsUI.labelFG)
                .frame(width: 112, alignment: .leading)

            content
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OtoSettingsUI.valueFG)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
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

#if DEBUG
#Preview("Settings — General") {
    OtoSettingsView()
        .environment(AppState.previewPopulated)
}

#Preview("Settings — Quiet Hours") {
    OtoSettingsView()
        .environment(AppState.previewPopulated)
}
#endif
