import AppKit
import SwiftUI
import UserNotifications

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case screenBreaks, smartPause, wellnessReminders, stats
    case alerts, sounds, hotkey
    case automation, devices, quietHours, notifications
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .screenBreaks: return "Screen Breaks"
        case .smartPause: return "Smart Pause"
        case .wellnessReminders: return "Wellness Reminders"
        case .stats: return "Stats"
        case .alerts: return "Alerts / Nudges"
        case .sounds: return "Sounds"
        case .hotkey: return "Keyboard Shortcuts"
        case .automation: return "Automation"
        case .devices: return "Audio Devices"
        case .quietHours: return "Quiet Hours"
        case .notifications: return "Notifications"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .screenBreaks: return "leaf.fill"
        case .smartPause: return "pause.fill"
        case .wellnessReminders: return "heart.fill"
        case .stats: return "chart.bar.fill"
        case .alerts: return "bell.badge.fill"
        case .sounds: return "speaker.wave.2.fill"
        case .hotkey: return "command"
        case .automation: return "wand.and.stars"
        case .devices: return "headphones"
        case .quietHours: return "moon.zzz.fill"
        case .notifications: return "bell.fill"
        case .about: return "info.circle.fill"
        }
    }

    /// Tint for the sidebar / page-header icon tile (the colourful rounded
    /// squares). A vivid, varied LookAway-style hue per section — independent
    /// of the teal brand accent used by controls.
    var tint: Color {
        switch self {
        case .general: return .tilePurple
        case .screenBreaks: return .tileGreen
        case .smartPause: return .tileIndigo
        case .wellnessReminders: return .tilePink
        case .stats: return .tileCoral
        case .alerts: return .tileOrange
        case .sounds: return .tileAmber
        case .hotkey: return .tileIndigo
        case .automation: return .tileGreen
        case .devices: return .tileBlue
        case .quietHours: return .tileIndigo
        case .notifications: return .tileCoral
        case .about: return .tileAmber
        }
    }

    /// Grouped layout for the sidebar (header title, then its rows).
    static let groups: [(title: String?, sections: [SettingsSection])] = [
        (nil, [.general]),
        ("Focus & Wellbeing", [.screenBreaks, .smartPause, .wellnessReminders, .stats]),
        ("Behavior & Feedback", [.alerts, .sounds, .hotkey]),
        ("Integrations", [.automation, .devices, .quietHours, .notifications]),
        ("Oto", [.about]),
    ]
}

struct OtoSettingsView: View {
    @Environment(AppState.self) private var state
    @State private var selected: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentPane
        }
        .frame(width: OtoSettingsUI.windowWidth, height: OtoSettingsUI.windowHeight)
        .otoSettingsBackdrop()
        .clipShape(RoundedRectangle(cornerRadius: OtoSettingsUI.windowRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OtoSettingsUI.windowRadius, style: .continuous)
                .strokeBorder(OtoSettingsUI.windowBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: OtoSettingsUI.windowShadow, radius: 28, x: 0, y: 18)
        .tint(.blue)
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .background(SettingsWindowConfigurator())
    }

    // MARK: Sidebar

    private var sidebar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [OtoSettingsUI.sidebarSurface, OtoSettingsUI.sidebarSurfaceDim],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(OtoSettingsUI.windowBorder.opacity(0.72), lineWidth: 1)
                }

            ScrollView {
                VStack(alignment: .leading, spacing: OtoSettingsUI.sidebarSectionSpacing) {
                    ForEach(Array(SettingsSection.groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 2) {
                            if let title = group.title {
                                Text(title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(OtoSettingsUI.tertiaryText)
                                    .padding(.leading, 10)
                                    .padding(.bottom, 4)
                            }
                            ForEach(group.sections) { section in
                                SettingsSidebarItem(
                                    section: section,
                                    isSelected: selected == section
                                ) { selected = section }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                // Keep real macOS traffic lights clear inside the glass panel.
                .padding(.top, 46)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: OtoSettingsUI.sidebarWidth)
        .padding(.leading, 8)
        .padding(.vertical, 8)
    }

    // MARK: Content

    private var contentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                SettingsTileIcon(name: selected.icon, tint: selected.tint, size: 24)
                Text(selected.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OtoSettingsUI.primaryText)
                Spacer()
            }
            .padding(.horizontal, OtoSettingsUI.contentPadding)
            .frame(height: OtoSettingsUI.topBarHeight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(OtoSettingsUI.hairline)
                    .frame(height: 1)
                    .opacity(0.70)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: OtoSettingsUI.sectionSpacing) {
                    selectedContent
                }
                .padding(.horizontal, OtoSettingsUI.contentPadding)
                .padding(.top, OtoSettingsUI.contentTopPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .background(OtoSettingsUI.contentSurface)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selected {
        case .general:           GeneralSettingsContent()
        case .screenBreaks:      ScreenBreaksSettingsContent()
        case .smartPause:        SmartPauseSettingsContent()
        case .wellnessReminders: WellnessRemindersSettingsContent()
        case .stats:             StatsSettingsContent()
        case .alerts:            AlertsSettingsContent()
        case .sounds:            SoundsSettingsContent()
        case .hotkey:            HotkeySettingsContent()
        case .automation:        AutomationSettingsContent()
        case .devices:           DeviceSettingsContent()
        case .quietHours:        QuietHoursSettingsContent()
        case .notifications:     NotificationsSettingsContent()
        case .about:             AboutSettingsContent()
        }
    }
}

/// A sidebar row matching the compact LookAway navigation: colorful square
/// icon, dense label, and a soft rounded selected pill.
private struct SettingsSidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                SettingsTileIcon(name: section.icon, tint: section.tint, size: 22)
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? OtoSettingsUI.primaryText : OtoSettingsUI.secondaryText.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(
                isSelected ? OtoSettingsUI.sidebarActive : (isHovering ? OtoSettingsUI.sidebarHover : Color.clear),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

/// Vivid rounded-square gradient icon tile — used for the settings sidebar and
/// page-header icons (LookAway style) as well as content rows and feature
/// screens (wellness navigation rows, the "stepped away" break screen).
struct SettingsTileIcon: View {
    let name: String
    let tint: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tint.opacity(1.0), tint.opacity(0.66)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .blendMode(.softLight)
            }
            .overlay {
                OtoIcon(name: name, size: size * 0.52, weight: .semibold)
                    .foregroundStyle(.white)
            }
            .shadow(color: tint.opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - General

private struct GeneralSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        @Bindable var wellness = state.wellness
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
            }

            SettingsContentSection(title: "Menu bar", divided: false) {
                MenuBarPreview()
                    .padding(.bottom, 4)
                HStack(alignment: .top, spacing: 12) {
                    MenuBarOptionColumn(title: "Live Status", isOn: $wellness.settings.breaksEnabled) {
                        MenuBarMiniRow(label: "Display") {
                            Picker("", selection: $wellness.settings.menuBarDisplay) {
                                ForEach(WellnessSettings.MenuBarDisplay.allCases, id: \.self) {
                                    Text($0.label).tag($0)
                                }
                            }
                            .labelsHidden().fixedSize()
                        }
                        MenuBarMiniRow(label: "Timer style") {
                            Picker("", selection: $wellness.settings.menuBarTimerStyle) {
                                ForEach(WellnessSettings.MenuBarTimerStyle.allCases, id: \.self) {
                                    Text($0.label).tag($0)
                                }
                            }
                            .labelsHidden().fixedSize()
                        }
                    }
                    MenuBarOptionColumn(title: "Screen Score", isOn: $wellness.settings.screenScoreEnabled) {
                        MenuBarMiniRow(label: "Display") {
                            Picker("", selection: $wellness.settings.screenScoreDisplay) {
                                ForEach(WellnessSettings.MenuBarDisplay.allCases, id: \.self) {
                                    Text($0.label).tag($0)
                                }
                            }
                            .labelsHidden().fixedSize()
                        }
                        MenuBarMiniRow(label: "Colored rings") {
                            Toggle("", isOn: $wellness.settings.screenScoreColoredRings)
                                .toggleStyle(.switch).labelsHidden()
                        }
                    }
                }
            }

            UpdatesSettingsSection()

            SettingsContentSection(title: "Onboarding") {
                SettingsFieldRow(label: "Setup") {
                    Button {
                        state.presentOnboarding()
                    } label: {
                        SettingsLinkButtonContent(label: "Run onboarding again")
                    }
                    .buttonStyle(.plain)
                }
                SettingsFieldRow(label: "Audio setup") {
                    Button {
                        NSApp.keyWindow?.close()
                        SpotlightWindowController.shared.present(activate: true)
                        state.presentFirstRunSetup()
                    } label: {
                        SettingsLinkButtonContent(label: "Set up audio automation")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

/// A titled, toggle-headed mini-card used by the General "Menu bar" block
/// (Live Status / Screen Score columns), matching LookAway's layout.
private struct MenuBarOptionColumn<Content: View>: View {
    let title: String
    @Binding var isOn: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(OtoSettingsUI.primaryText)
                Spacer()
                Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden()
                    .scaleEffect(0.85)
            }
            .frame(height: 28)

            Rectangle()
                .fill(OtoSettingsUI.hairline)
                .frame(height: 1)
                .opacity(0.7)

            content
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
        .background(OtoSettingsUI.panelSurface, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous)
                .strokeBorder(OtoSettingsUI.cardStroke, lineWidth: 1)
        }
    }
}

/// Compact label-left / control-right row for the menu-bar option columns
/// (narrower than `SettingsFieldRow`, which has a fixed wide label column).
private struct MenuBarMiniRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(OtoSettingsUI.labelFG)
            Spacer(minLength: 6)
            content
        }
        .frame(minHeight: 31)
    }
}

/// General → Updates: the Sparkle auto-update controls.
private struct UpdatesSettingsSection: View {
    private let updater = UpdateController.shared
    @State private var autoCheck = UpdateController.shared.automaticallyChecksForUpdates
    @State private var autoDownload = UpdateController.shared.automaticallyDownloadsUpdates

    var body: some View {
        SettingsContentSection(
            title: "Updates",
            footnote: updater.isAvailable
                ? nil
                : "The updater isn't bundled in this build yet — add the Sparkle package to enable update delivery."
        ) {
            SettingsFieldRow(label: "Automatically check for updates") {
                Toggle("", isOn: $autoCheck)
                    .toggleStyle(.switch).labelsHidden()
                    .onChange(of: autoCheck) { _, v in updater.automaticallyChecksForUpdates = v }
            }
            SettingsFieldRow(label: "Automatically download updates") {
                Toggle("", isOn: $autoDownload)
                    .toggleStyle(.switch).labelsHidden()
                    .onChange(of: autoDownload) { _, v in updater.automaticallyDownloadsUpdates = v }
            }
            SettingsFieldRow(label: "Updates") {
                Button("Check for updates…") { updater.checkForUpdates() }
                    .controlSize(.small)
                    .disabled(!updater.isAvailable)
            }
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

struct TimePickerRow: View {
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

/// Grouped LookAway-style settings card with an optional header, compact row
/// padding, and subtle dividers between direct child rows.
///
/// `footnote` renders below the card as small muted text — the right
/// place for non-actionable descriptions like "Attempts above the cap
/// reset automatically".
struct SettingsContentSection<Content: View>: View {
    var title: String? = nil
    var footnote: String? = nil
    var verticalPadding: CGFloat = 5
    var divided: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OtoSettingsUI.primaryText.opacity(0.86))
                    .padding(.leading, 10)
            }

            Group {
                if divided {
                    DividedRows { content }
                } else {
                    VStack(spacing: 8) { content }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 10)
            .otoSectionCard(cornerRadius: OtoSettingsUI.cardRadius)

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(OtoSettingsUI.tertiaryText)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lays out child rows with a hairline divider between each — the native
/// grouped-list look — without callers having to track which row is last.
/// Uses `_VariadicView` so it works on the macOS 14 deployment target
/// (`Group(subviews:)` requires macOS 15).
private struct DividedRows<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        _VariadicView.Tree(DividedRowsLayout()) { content }
    }
}

private struct DividedRowsLayout: _VariadicView.MultiViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != lastID {
                    Rectangle()
                        .fill(OtoSettingsUI.hairline)
                        .frame(height: 1)
                        .padding(.leading, 0)
                        .opacity(0.7)
                }
            }
        }
    }
}

/// Full-width pill-button content used by link/action rows (Run setup again,
/// View Oto on GitHub). Renders the label + a trailing "↗" affordance, with
/// a hover state so the row feels live instead of like a static label. The
/// caller wraps it in a Button/Link with `.buttonStyle(.plain)` so its own
/// click area covers the whole pill.
struct SettingsLinkButtonContent: View {
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
        .frame(height: 25)
        .otoControlGlass(
            in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous),
            interactive: true
        )
        .foregroundStyle(OtoSettingsUI.valueFG)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }
}

struct SettingsFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(OtoSettingsUI.labelFG)
                .frame(minWidth: 0, alignment: .leading)

            content
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OtoSettingsUI.valueFG)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(minHeight: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 34)
    }
}

private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = OtoSettingsUI.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .otoSectionCard(cornerRadius: OtoSettingsUI.cardRadius)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .background(OtoSettingsUI.panelSurfaceRaised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(OtoSettingsUI.secondaryText)
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
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.hasShadow = true
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
