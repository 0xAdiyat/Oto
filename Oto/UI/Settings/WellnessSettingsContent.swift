import SwiftUI

// MARK: - Screen Breaks

/// The Screen Breaks settings page, modelled on LookAway's: focus interval +
/// break length, long-breaks / office-hours disclosures, the Casual / Balanced
/// / Hardcore enforcement picker, snooze limits, and the double-escape action.
struct ScreenBreaksSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var showCustomize = false

    var body: some View {
        @Bindable var wellness = state.wellness
        let s = $wellness.settings

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "General") {
                SettingsMenuRow(
                    label: "Show a break after",
                    options: WellnessPresets.breakIntervals.map { ($0, "\($0) minutes") },
                    selection: s.breakIntervalMinutes,
                    suffix: "of focused screen time"
                )
                SettingsMenuRow(
                    label: "Break duration",
                    options: WellnessPresets.breakLengths.map { ($0, durationName($0)) },
                    selection: s.breakLengthSeconds
                )
            }

            SettingsContentSection {
                NavigationLikeRow(
                    icon: "paintbrush.fill",
                    tint: .otoSage,
                    title: "Customize break screen",
                    value: s.breakScreenStyle.wrappedValue.background.label
                ) { showCustomize = true }
                Divider().background(OtoSettingsUI.glassStroke)
                LongBreaksDisclosure(settings: s)
                Divider().background(OtoSettingsUI.glassStroke)
                OfficeHoursDisclosure(settings: s)
            }

            // Break enforcement
            VStack(alignment: .leading, spacing: 8) {
                Text("BREAK ENFORCEMENT")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .padding(.leading, 4)

                HStack(spacing: 10) {
                    ForEach(WellnessSettings.BreakEnforcement.allCases, id: \.self) { mode in
                        EnforcementCard(
                            mode: mode,
                            isSelected: wellness.settings.enforcement == mode
                        ) { wellness.settings.enforcement = mode }
                    }
                }

                VStack(spacing: 4) {
                    SettingsMenuRow(
                        label: "Snoozes allowed per session",
                        options: snoozeOptions,
                        selection: s.snoozesPerSession
                    )
                    SettingsMenuRow(
                        label: "Snoozes allowed per day",
                        options: snoozeOptions,
                        selection: s.snoozesPerDay
                    )
                    SettingsFieldRow(label: "Show snoozes remaining after snoozing") {
                        Toggle("", isOn: s.showSnoozesRemaining)
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(OtoSettingsUI.cardFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsContentSection(title: "More") {
                SettingsMenuRow(
                    label: "Double escape action on break screen",
                    options: WellnessSettings.DoubleEscapeAction.allCases.map { ($0, $0.label) },
                    selection: s.doubleEscapeAction
                )
                SettingsFieldRow(label: "Let me \"End break\" early if nearly done") {
                    Toggle("", isOn: s.endBreakEarlyIfNearlyDone)
                        .toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Lock my Mac automatically when a break starts") {
                    Toggle("", isOn: s.lockMacOnBreakStart)
                        .toggleStyle(.switch).labelsHidden()
                }
            }
        }
        .sheet(isPresented: $showCustomize) {
            CustomizeBreakScreenView(style: s.breakScreenStyle) { showCustomize = false }
        }
    }

    private func durationName(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) minute" : "\(seconds) seconds"
    }

    private var snoozeOptions: [(value: Int, label: String)] {
        [(-1, "No limit"), (1, "1"), (2, "2"), (3, "3"), (5, "5"), (10, "10")]
    }
}

// MARK: Enforcement card

private struct EnforcementCard: View {
    let mode: WellnessSettings.BreakEnforcement
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch mode {
        case .casual:   return "forward.fill"
        case .balanced: return "circle.dashed"
        case .hardcore: return "nosign"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Faux "Skip Break" preview bar with a sunset gradient.
                ZStack {
                    LinearGradient(
                        colors: [Color.otoYellow.opacity(0.55), Color.otoNavy.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    HStack(spacing: 6) {
                        OtoIcon(name: icon, size: 11).foregroundStyle(.white.opacity(0.95))
                        Text("Skip Break")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .opacity(mode == .hardcore ? 0.5 : 1)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(OtoUI.primaryFG)
                    Text(mode.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(OtoSettingsUI.cardFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            // Functional selected-state highlight (teal); no stroke when unselected.
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                        .strokeBorder(Color.otoTeal, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Disclosures

private struct LongBreaksDisclosure: View {
    @Binding var binding: WellnessSettings
    @State private var expanded = false

    init(settings: Binding<WellnessSettings>) {
        self._binding = settings
    }

    var body: some View {
        VStack(spacing: 10) {
            DisclosureHeader(
                icon: "hourglass",
                tint: .otoTeal,
                title: "Long breaks",
                value: binding.longBreaksEnabled
                    ? "Every \(binding.longBreakEvery)th break is a \(binding.longBreakMinutes) mins long break"
                    : "Disabled",
                expanded: $expanded
            )
            if expanded {
                VStack(spacing: 4) {
                    SettingsFieldRow(label: "Enable long breaks") {
                        Toggle("", isOn: $binding.longBreaksEnabled).toggleStyle(.switch).labelsHidden()
                    }
                    SettingsMenuRow(
                        label: "Frequency",
                        options: [2, 3, 4, 5, 6].map { ($0, "Every \($0)th break") },
                        selection: $binding.longBreakEvery
                    )
                    SettingsMenuRow(
                        label: "Long break length",
                        options: [2, 3, 5, 10].map { ($0, "\($0) minutes") },
                        selection: $binding.longBreakMinutes
                    )
                }
                .disabled(!binding.longBreaksEnabled)
            }
        }
    }
}

private struct OfficeHoursDisclosure: View {
    @Binding var binding: WellnessSettings
    @State private var expanded = false

    init(settings: Binding<WellnessSettings>) {
        self._binding = settings
    }

    var body: some View {
        VStack(spacing: 10) {
            DisclosureHeader(
                icon: "clock",
                tint: .otoNavy,
                title: "Office hours",
                value: binding.officeHoursEnabled ? "Enabled" : "Disabled",
                expanded: $expanded
            )
            if expanded {
                VStack(spacing: 4) {
                    SettingsFieldRow(label: "Only run breaks during office hours") {
                        Toggle("", isOn: $binding.officeHoursEnabled).toggleStyle(.switch).labelsHidden()
                    }
                    SettingsFieldRow(label: "From") {
                        TimePickerRow(label: "", minutes: $binding.officeHoursStartMinute)
                            .disabled(!binding.officeHoursEnabled)
                    }
                    SettingsFieldRow(label: "To") {
                        TimePickerRow(label: "", minutes: $binding.officeHoursEndMinute)
                            .disabled(!binding.officeHoursEnabled)
                    }
                }
            }
        }
    }
}

/// A tappable row that looks like a disclosure header but pushes/opens
/// something instead of expanding (e.g. "Customize break screen" → sheet).
struct NavigationLikeRow: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsTileIcon(name: icon, tint: tint, size: 24)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OtoSettingsUI.valueFG)
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                        .lineLimit(1)
                }
                OtoIcon(name: "chevron.right", size: 10)
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DisclosureHeader: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    @Binding var expanded: Bool

    var body: some View {
        Button {
            withAnimation(OtoUI.revealEase) { expanded.toggle() }
        } label: {
            HStack(spacing: 10) {
                SettingsTileIcon(name: icon, tint: tint, size: 24)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OtoSettingsUI.valueFG)
                Spacer()
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoSettingsUI.quietFG)
                    .lineLimit(1)
                OtoIcon(name: expanded ? "chevron.down" : "chevron.right", size: 10)
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable menu row

/// Label on the left, a `.menu` picker on the right, with an optional trailing
/// suffix label ("of focused screen time").
struct SettingsMenuRow<T: Hashable>: View {
    let label: String
    let options: [(value: T, label: String)]
    @Binding var selection: T
    var suffix: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OtoSettingsUI.valueFG)
            Spacer(minLength: 8)
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
            }
            .labelsHidden()
            .fixedSize()
            if let suffix {
                Text(suffix)
                    .font(.system(size: 13))
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Wellness Reminders

struct WellnessRemindersSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var wellness = state.wellness
        let s = $wellness.settings

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            HStack(alignment: .top, spacing: 14) {
                ReminderColumn(
                    kind: .posture,
                    title: "Posture Reminder",
                    subtitle: "Helps you sit upright and avoid strain.",
                    enabled: s.postureReminderEnabled,
                    minutes: s.postureReminderMinutes,
                    style: s.postureStyle
                )
                ReminderColumn(
                    kind: .blink,
                    title: "Blink Reminder",
                    subtitle: "Nudges you to blink at healthy intervals.",
                    enabled: s.blinkReminderEnabled,
                    minutes: s.blinkReminderMinutes,
                    style: s.blinkStyle
                )
            }

            SettingsContentSection(title: "Common settings") {
                SettingsFieldRow(label: "Dim the screen when showing reminders") {
                    Toggle("", isOn: s.dimScreenForReminders).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Keep reminders active during smart-pause") {
                    Toggle("", isOn: s.remindersActiveDuringSmartPause).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Prevent reminders from showing in screen recordings") {
                    Toggle("", isOn: s.hideRemindersInScreenRecording).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Reset timers after break") {
                    Toggle("", isOn: s.resetReminderTimersAfterBreak).toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }
}

/// One reminder's configuration column (Posture / Blink): preview header,
/// enable toggle, cadence, size, 9-point position picker, and sound chooser.
private struct ReminderColumn: View {
    @Environment(AppState.self) private var state
    let kind: WellnessReminderManager.ReminderKind
    let title: String
    let subtitle: String
    @Binding var enabled: Bool
    @Binding var minutes: Int
    @Binding var style: ReminderStyle

    private static let cadences = [5, 10, 20, 30, 45, 60]
    private static let sounds: [(value: String?, label: String)] = [
        (nil, "None"), ("Glass", "Glass"), ("Submarine", "Submarine"),
        ("Ping", "Ping"), ("Pop", "Pop"), ("Tink", "Tink"), ("Funk", "Funk"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OtoUI.primaryFG)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(OtoSettingsUI.quietFG)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { state.previewReminder(kind) } label: {
                    OtoIcon(name: "play.circle.fill", size: 20)
                        .foregroundStyle(Color.otoTeal)
                }
                .buttonStyle(.plain)
                .help("Preview")
            }

            Divider().background(OtoSettingsUI.glassStroke)

            VStack(spacing: 4) {
                SettingsFieldRow(label: "Enabled") {
                    Toggle("", isOn: $enabled).toggleStyle(.switch).labelsHidden()
                }
                SettingsMenuRow(
                    label: "Show every",
                    options: Self.cadences.map { ($0, "\($0) minutes") },
                    selection: $minutes
                )
                SettingsMenuRow(
                    label: "Size",
                    options: ReminderStyle.Size.allCases.map { ($0, $0.title) },
                    selection: $style.size
                )
                SettingsMenuRow(
                    label: "Sound",
                    options: Self.sounds,
                    selection: $style.soundName
                )
            }
            .disabled(!enabled)

            Text("Position")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OtoSettingsUI.labelFG)
            PositionGridPicker(position: $style.position)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OtoSettingsUI.cardFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
    }
}

/// 3×3 on-screen position picker laid over a mini "screen", LookAway-style.
struct PositionGridPicker: View {
    @Binding var position: ReminderStyle.Position

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(0..<3, id: \.self) { col in
                        let pos = ReminderStyle.Position.from(row: row, col: col)
                        Button { position = pos } label: {
                            Circle()
                                .fill(position == pos ? Color.otoTeal : Color.white.opacity(0.5))
                                .frame(width: position == pos ? 13 : 9, height: position == pos ? 13 : 9)
                                .overlay {
                                    if position == pos {
                                        Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.otoSage.opacity(0.55), Color.otoNavy.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Smart Pause

struct SmartPauseSettingsContent: View {
    @Environment(AppState.self) private var state
    @State private var appChooser: SmartPauseSourceKind?
    @State private var hasCalendarAccess = SmartPauseSourceDetector.hasCalendarAccess

    var body: some View {
        @Bindable var wellness = state.wellness
        let s = $wellness.settings

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection {
                SettingsFieldRow(label: "Enable Smart Pause") {
                    Toggle("", isOn: s.smartPauseEnabled).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Don't show breaks while I'm typing, dragging, or dictating") {
                    Toggle("", isOn: s.suppressBreaksWhileTyping).toggleStyle(.switch).labelsHidden()
                }
            }

            SettingsContentSection(
                title: "Automatically pause during",
                footnote: "Meetings, video, gaming and screen-recording detection is best-effort and may not catch every app."
            ) {
                SmartPauseSourceRow(
                    icon: "video.fill", tint: .otoNavy,
                    title: "Meetings or Calls",
                    subtitle: "Pauses breaks during calls and online meetings",
                    isOn: s.smartPauseSources.meetingsCalls
                )
                SmartPauseSourceRow(
                    icon: "play.rectangle.fill", tint: .otoTeal,
                    title: "Video playback",
                    subtitle: "Pauses breaks while a video is playing",
                    isOn: s.smartPauseSources.videoPlayback
                )
                SmartPauseSourceRow(
                    icon: "calendar", tint: .otoAlert,
                    title: "Calendar Events",
                    subtitle: "Pauses breaks when a calendar event is ongoing",
                    isOn: s.smartPauseSources.calendarEvents,
                    accessory: hasCalendarAccess ? nil : .button("Grant permissions…") {
                        SmartPauseSourceDetector.requestCalendarAccess { granted in
                            hasCalendarAccess = granted
                        }
                    }
                )
                SmartPauseSourceRow(
                    icon: "brain.head.profile", tint: .otoSage,
                    title: "Deep focus apps",
                    subtitle: "Pauses breaks when your chosen apps are active",
                    isOn: s.smartPauseSources.deepFocusApps,
                    accessory: .button("Options") { appChooser = .deepFocus }
                )
                SmartPauseSourceRow(
                    icon: "gamecontroller.fill", tint: .otoYellow,
                    title: "Gaming",
                    subtitle: "Pauses breaks while you're playing a game",
                    isOn: s.smartPauseSources.gaming,
                    accessory: .button("Options") { appChooser = .gaming }
                )
                SmartPauseSourceRow(
                    icon: "record.circle", tint: .otoAlert,
                    title: "Screen recording or sharing",
                    subtitle: "Pauses breaks when you're sharing or recording your screen",
                    isOn: s.smartPauseSources.screenRecording
                )
            }

            SettingsContentSection {
                SettingsMenuRow(
                    label: "Cooldown after smart pause ends",
                    options: WellnessPresets.cooldowns.map { ($0, WellnessPresets.secondsLabel($0)) },
                    selection: s.smartPauseCooldownSeconds
                )
            }

            SettingsContentSection(
                title: "Idle Tracking",
                footnote: "Oto pauses or resets the focus timer based on your activity when you step away."
            ) {
                SettingsMenuRow(
                    label: "Pause after being idle for",
                    options: WellnessPresets.idleThresholds.map { ($0, WellnessPresets.secondsLabel($0)) },
                    selection: s.idlePauseSeconds
                )
                SettingsFieldRow(label: "Pause when the screen is locked") {
                    Toggle("", isOn: s.pauseOnScreenLock).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Pause when the display sleeps") {
                    Toggle("", isOn: s.pauseOnDisplaySleep).toggleStyle(.switch).labelsHidden()
                }
                SettingsMenuRow(
                    label: "Pause or resume when I step away",
                    options: WellnessSettings.IdleReturnBehavior.allCases.map { ($0, $0.label) },
                    selection: s.idleReturnBehavior
                )
                SettingsFieldRow(label: "Show \"Stepped Away?\" dialog on returning from idle") {
                    Toggle("", isOn: s.showSteppedAwayDialog)
                        .toggleStyle(.switch).labelsHidden()
                        .disabled(wellness.settings.idleReturnBehavior != .ask)
                }
            }
        }
        .sheet(item: $appChooser) { kind in
            SmartPauseAppChooser(
                kind: kind,
                bundleIDs: kind == .deepFocus ? s.smartPauseSources.deepFocusBundleIDs
                                              : s.smartPauseSources.gamingBundleIDs
            ) { appChooser = nil }
        }
        .onAppear { hasCalendarAccess = SmartPauseSourceDetector.hasCalendarAccess }
    }
}

enum SmartPauseSourceKind: String, Identifiable {
    case deepFocus, gaming
    var id: String { rawValue }
    var title: String { self == .deepFocus ? "Deep focus apps" : "Games" }
}

/// One row in the "Automatically pause during" list: icon + title/subtitle, an
/// optional trailing button (Options / Grant permissions…), and a switch.
private struct SmartPauseSourceRow: View {
    enum Accessory { case button(String, () -> Void) }

    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var accessory: Accessory? = nil

    var body: some View {
        HStack(spacing: 12) {
            SettingsTileIcon(name: icon, tint: tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(OtoSettingsUI.valueFG)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(OtoSettingsUI.quietFG)
            }
            Spacer()
            if case let .button(label, action)? = accessory {
                Button(label, action: action).controlSize(.small)
            }
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// Sheet to pick which apps trigger the deep-focus / gaming pause. Lists the
/// currently running regular apps plus any already-selected bundle IDs.
private struct SmartPauseAppChooser: View {
    let kind: SmartPauseSourceKind
    @Binding var bundleIDs: [String]
    var onClose: () -> Void

    private struct AppItem: Identifiable {
        let id: String       // bundle ID
        let name: String
    }

    private var items: [AppItem] {
        var seen = Set<String>()
        var result: [AppItem] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(AppItem(id: id, name: app.localizedName ?? id))
        }
        for id in bundleIDs where !seen.contains(id) {
            seen.insert(id)
            result.append(AppItem(id: id, name: id))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Choose \(kind.title)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OtoUI.primaryFG)
                Spacer()
                Button("Done", action: onClose).keyboardShortcut(.defaultAction)
            }
            Text("Breaks pause while one of these apps is frontmost.")
                .font(.system(size: 11))
                .foregroundStyle(OtoSettingsUI.quietFG)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        Button {
                            toggle(item.id)
                        } label: {
                            HStack(spacing: 10) {
                                OtoIcon(name: bundleIDs.contains(item.id) ? "checkmark.circle.fill" : "circle", size: 16)
                                    .foregroundStyle(bundleIDs.contains(item.id) ? Color.otoTeal : OtoSettingsUI.quietFG)
                                Text(item.name)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(OtoSettingsUI.valueFG)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(OtoSettingsUI.subtleFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.controlRadius, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 280)
        }
        .padding(22)
        .frame(width: 420)
        .background(Color.otoSettingsSurface)
        .focusEffectDisabled()
    }

    private func toggle(_ id: String) {
        if let idx = bundleIDs.firstIndex(of: id) { bundleIDs.remove(at: idx) }
        else { bundleIDs.append(id) }
    }
}

// MARK: - Sounds

struct SoundsSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var wellness = state.wellness
        let s = $wellness.settings

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Break Sounds") {
                SettingsFieldRow(label: "Play sound when a break starts") {
                    Toggle("", isOn: s.playBreakStartSound).toggleStyle(.switch).labelsHidden()
                }
                SettingsFieldRow(label: "Play sound when a break ends") {
                    Toggle("", isOn: s.playBreakEndSound).toggleStyle(.switch).labelsHidden()
                }
            }
            SettingsContentSection(title: "Reminder Sounds") {
                SettingsFieldRow(label: "Play sound with wellness reminders") {
                    Toggle("", isOn: s.playReminderSound).toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }
}

// MARK: - Alerts / Nudges

struct AlertsSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var wellness = state.wellness
        let s = $wellness.settings

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(
                title: "Pre-break Nudge",
                footnote: "A heads-up before the screen blurs, so a break never catches you mid-thought."
            ) {
                SettingsMenuRow(
                    label: "Warn me before a break",
                    options: [(0, "Off"), (30, "30 seconds"), (60, "1 minute"), (120, "2 minutes")],
                    selection: s.preBreakWarningSeconds
                )
            }
        }
    }
}

// MARK: - Stats (placeholder until the stats phase)

struct StatsSettingsContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let stats = state.wellnessStats
        let today = stats.today

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(title: "Today") {
                HStack(spacing: 10) {
                    StatTile(icon: "bolt.fill", tint: .otoYellow,
                             value: WellnessStatsStore.focusLabel(seconds: today.focusSeconds),
                             caption: "Focused time")
                    StatTile(icon: "leaf.fill", tint: .otoTeal,
                             value: "\(today.breaksCompleted)",
                             caption: "Breaks taken")
                    StatTile(icon: "forward.fill", tint: .otoAlert,
                             value: "\(today.breaksSkipped)",
                             caption: "Breaks skipped")
                    StatTile(icon: "heart.fill", tint: .otoSage,
                             value: "\(today.remindersShown)",
                             caption: "Reminders")
                }
            }

            SettingsContentSection(
                title: "Last 7 Days",
                footnote: "Focused screen time per day. \(stats.weekBreaksCompleted) breaks taken this week."
            ) {
                WeeklyFocusBars(days: stats.lastSevenDays, height: 120)
                    .padding(.vertical, 6)
            }

            WebsiteUsageSection()
        }
    }
}

/// LookAway "Website usage stats": today's top domains plus per-browser opt-in
/// toggles. Tracking only runs for enabled browsers and needs Automation access.
private struct WebsiteUsageSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var wellness = state.wellness
        let domains = state.websiteUsage.topDomains(limit: 6)

        VStack(spacing: OtoSettingsUI.sectionSpacing) {
            SettingsContentSection(
                title: "Website usage stats",
                footnote: domains.isEmpty
                    ? "Enable a browser below and grant Automation access to start tracking active-tab time."
                    : "Active-tab time today, top sites first."
            ) {
                if domains.isEmpty {
                    HStack(spacing: 8) {
                        OtoIcon(name: "globe", size: 14).foregroundStyle(OtoSettingsUI.quietFG)
                        Text("No website usage tracked yet today.")
                            .font(.system(size: 12)).foregroundStyle(OtoSettingsUI.quietFG)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(domains) { item in
                        HStack(spacing: 10) {
                            OtoIcon(name: "globe", size: 14).foregroundStyle(Color.otoTeal)
                            Text(item.domain)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(OtoSettingsUI.valueFG)
                                .lineLimit(1)
                            Spacer()
                            Text(WebsiteUsageStore.durationLabel(seconds: item.seconds))
                                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                                .foregroundStyle(OtoSettingsUI.quietFG)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            SettingsContentSection(
                title: "Enable browsers where you want to track website usage"
            ) {
                ForEach(BrowserKind.allCases) { browser in
                    SettingsFieldRow(label: browser.displayName) {
                        Toggle("", isOn: Binding(
                            get: { wellness.settings.trackedBrowsers.contains(browser) },
                            set: { on in
                                if on { wellness.settings.trackedBrowsers.insert(browser) }
                                else { wellness.settings.trackedBrowsers.remove(browser) }
                            }
                        ))
                        .toggleStyle(.switch).labelsHidden()
                    }
                }
            }
        }
    }
}
