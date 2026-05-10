
import Combine
import SwiftUI

/// Spotlight-style root view: borderless transparent window contents.
/// Header pill on top, filter bar, then the rules panel.
struct MainWindowView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings

    @State private var headerAppeared = false
    @State private var filtersAppeared = false
    @State private var panelAppeared = false

    @State private var revealTask: Task<Void, Never>?
    @State private var filter: RuleFilter = .all
    @State private var sheet: ActiveSheet?
    @State private var editingRule: Rule? = nil

    enum ActiveSheet: Identifiable {
        case addRule, templates, profiles, devices, about
        var id: String {
            switch self {
            case .addRule: return "add"
            case .templates: return "templates"
            case .profiles: return "profiles"
            case .devices: return "devices"
            case .about: return "about"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 12) {
                HeaderPill(
                    onAdd: { sheet = .addRule },
                    onTemplates: { sheet = .templates },
                    onShowProfiles: { sheet = .profiles },
                    onShowDevices: { sheet = .devices },
                    onShowSettings: { openSettings() },
                    onShowAbout: { sheet = .about }
                )
                .opacity(headerAppeared ? 1 : 0)
                .blur(radius: headerAppeared ? 0 : 7)

                FilterTabsBar(filter: $filter)
                    .opacity(filtersAppeared ? 1 : 0)
                    .offset(y: filtersAppeared ? 0 : -4)

                RulesPanel(
                    filter: filter,
                    onEdit: { rule in editingRule = rule }
                )
                .opacity(panelAppeared ? 1 : 0)
                .scaleEffect(panelAppeared ? 1 : 0.985, anchor: .top)
                .blur(radius: panelAppeared ? 0 : 5)
                .offset(y: panelAppeared ? 0 : -8)

                footerBar
                    .opacity(panelAppeared ? 1 : 0)
                    .offset(y: panelAppeared ? 0 : -4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 56)
            .padding(.bottom, 56)

            if state.isShowingFirstRunSetup {
                firstRunOverlay
                    .transition(.opacity)
            } else if isSheetActive {
                sheetOverlay
                    .transition(.opacity)
            }

            SpotlightFooterShortcutCarriers(
                canShowActions: editingRule != nil,
                onShowActions: { editingRule = nil },
                onNewRule: { sheet = .addRule },
                onOpenSettings: { openSettings() }
            )
            .frame(width: 0, height: 0)
            .hidden()

            UndoCommandCarriers()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Spotlight panel follows the system theme. Token colours
        // (panelTint, mutedFG, secondaryFG, primaryFG, strokeColor, …) flip
        // polarity per appearance via `OtoUI.adaptiveTone`, so light mode
        // gets a bright panel with dark text and dark mode gets the inverse.
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .animation(.easeOut(duration: 0.18), value: isSheetActive)
        .animation(.easeOut(duration: 0.18), value: state.isShowingFirstRunSetup)
        .onAppear { runRevealAnimation() }
        .onReceive(NotificationCenter.default.publisher(for: .spotlightWindowDidPresent)) { _ in
            runRevealAnimation()
        }
        // Suppress the spotlight controller's auto-hide while any sheet owns
        // the panel. Otherwise a brief focus blip from the sheet's own
        // controls (or a system permission alert spawned by the sheet's
        // initial work, e.g. IOBluetooth in DevicesSheet) hides the window
        // mid-interaction.
        .onChange(of: isSheetActive) { _, active in
            SpotlightWindowController.shared.suppressAutoHide = active || state.isShowingFirstRunSetup
        }
        .onChange(of: state.isShowingFirstRunSetup) { _, showing in
            SpotlightWindowController.shared.suppressAutoHide = showing || isSheetActive
        }
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            footerGroup(key: "Return", label: editingRule == nil ? "Edit Rule" : "Edit Rule")

            footerDivider

            footerGroup(key: "⌘K", label: "Actions")
                .opacity(editingRule == nil ? 0.72 : 1)

            footerDivider

            footerGroup(key: "⌘N", label: "New Rule")

            footerDivider

            footerGroup(key: "⌘,", label: "Settings")

            Spacer()

            Text(footerHint)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(OtoUI.mutedFG)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(width: OtoUI.pillWidth, height: OtoUI.spotlightFooterHeight)
        // Tint stacked in the BACKGROUND alongside the material so it sits
        // behind the footer text/keys, not over them.
        .background {
            let shape = RoundedRectangle(cornerRadius: OtoUI.panelRadius, style: .continuous)
            ZStack {
                shape.fill(.thickMaterial)
                shape.fill(OtoUI.panelTint)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.panelRadius, style: .continuous)
                .strokeBorder(OtoUI.strokeColor, lineWidth: OtoUI.strokeWidth)
        }
        .shadow(
            color: OtoUI.shadowMedium,
            radius: OtoUI.shadowMediumRadius,
            x: 0,
            y: OtoUI.shadowMediumY
        )
    }

    private var footerHint: String {
        if let rule = editingRule {
            return "Return edits \(triggerSummary(for: rule).lowercased())"
        }
        return "Open a rule menu or use shortcuts"
    }

    private func footerGroup(key: String, label: String) -> some View {
        HStack(spacing: 6) {
            footerKey(key)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OtoUI.primaryFG)
        }
    }

    private func footerKey(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(OtoUI.primaryFG)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous)
                    .strokeBorder(OtoUI.strokeColor, lineWidth: 1)
            }
    }

    private var footerDivider: some View {
        Rectangle()
            .fill(OtoUI.dividerColor)
            .frame(width: 1, height: 14)
    }

    private func triggerSummary(for rule: Rule) -> String {
        switch rule.trigger {
        case .deviceConnects(_, let name):
            return name
        case .deviceDisconnects(_, let name):
            return name
        case .anyBluetoothConnects:
            return "Bluetooth rule"
        case .systemWakes:
            return "wake rule"
        case .appLaunches(_, let appName):
            return appName
        }
    }

    // MARK: - Sheet overlay

    private var isSheetActive: Bool {
        sheet != nil || editingRule != nil
    }

    private var firstRunOverlay: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            FirstRunSetupSheet()
                .environment(state)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var sheetOverlay: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismissActiveSheet() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Dismiss")

            currentSheetContent
                .transition(.scale(scale: 0.96).combined(with: .opacity))

            Button("Cancel") { dismissActiveSheet() }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .environment(\.otoDismiss, OtoDismissAction(action: dismissActiveSheet))
    }

    @ViewBuilder
    private var currentSheetContent: some View {
        if let rule = editingRule {
            RuleEditorSheet(existing: rule).environment(state)
        } else if let active = sheet {
            switch active {
            case .addRule:
                RuleEditorSheet(existing: nil).environment(state)
            case .templates:
                TemplatesSheet().environment(state)
            case .profiles:
                ProfilesSheet().environment(state)
            case .devices:
                DevicesSheet().environment(state)
            case .about:
                AboutSheet()
            }
        }
    }

    private func dismissActiveSheet() {
        if editingRule != nil {
            editingRule = nil
        } else {
            sheet = nil
        }
    }

    private func runRevealAnimation() {
        revealTask?.cancel()

        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            headerAppeared = false
            filtersAppeared = false
            panelAppeared = false
        }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            withAnimation(OtoUI.revealEase) { headerAppeared = true }

            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            withAnimation(OtoUI.revealEase) { filtersAppeared = true }

            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            withAnimation(OtoUI.trimEase) { panelAppeared = true }
        }
    }
}

// MARK: - Undo carriers

private struct UndoCommandCarriers: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Button("Undo") { state.store.undoManager.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!state.store.undoManager.canUndo)
            Button("Redo") { state.store.undoManager.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!state.store.undoManager.canRedo)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct SpotlightFooterShortcutCarriers: View {
    let canShowActions: Bool
    let onShowActions: () -> Void
    let onNewRule: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            Button("Show Actions", action: onShowActions)
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!canShowActions)

            Button("New Rule", action: onNewRule)
                .keyboardShortcut("n", modifiers: .command)

            Button("Settings", action: onOpenSettings)
                .keyboardShortcut(",", modifiers: .command)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Filter

enum RuleFilter: String, CaseIterable, Identifiable {
    case all, active, inactive
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var tint: Color {
        switch self {
        case .all:      return .otoTeal
        case .active:   return .otoYellow
        case .inactive: return .otoAlert
        }
    }
}

enum BulkAction {
    case pauseAll, resumeAll

    var iconName: String {
        switch self {
        case .pauseAll:  return "pause.fill"
        case .resumeAll: return "play.fill"
        }
    }

    var menuLabel: String {
        switch self {
        case .pauseAll:  return "Pause all rules"
        case .resumeAll: return "Resume all rules"
        }
    }

    var helpText: String {
        switch self {
        case .pauseAll:  return "Click again to pause every rule"
        case .resumeAll: return "Click again to resume every rule"
        }
    }

    func isMeaningful(rules: [Rule]) -> Bool {
        switch self {
        case .pauseAll:  return rules.contains { $0.enabled }
        case .resumeAll: return rules.contains { !$0.enabled }
        }
    }
}

struct FilterTabsBar: View {
    @Environment(AppState.self) private var state
    @Binding var filter: RuleFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RuleFilter.allCases) { f in
                let isOn = filter == f
                chip(for: f, isOn: isOn)
            }
            Spacer()
            if filter != .all {
                Text("Drag to reorder available in All")
                    .font(.system(size: 10))
                    .foregroundStyle(OtoUI.mutedFG)
            }
            QuietHoursStatusChip()
        }
        .frame(width: OtoUI.pillWidth)
        .padding(.horizontal, 4)
        .animation(.easeOut(duration: 0.14), value: filter)
    }

    @ViewBuilder
    private func chip(for f: RuleFilter, isOn: Bool) -> some View {
        let tint = f.tint
        let action = bulkAction(for: f)
        let showActionHint = isOn && action != nil

        Button {
            if isOn, let action {
                performBulkAction(action)
            } else {
                filter = f
            }
        } label: {
            HStack(spacing: 5) {
                Text(f.label)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count(for: f))")
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isOn ? tint.opacity(0.18) : OtoUI.rowIdle, in: Capsule())
                if showActionHint, let icon = action?.iconName {
                    OtoIcon(name: icon, size: 8)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isOn ? tint.opacity(0.18) : Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? tint.opacity(0.45) : OtoUI.dividerColor, lineWidth: 1)
            }
            .foregroundStyle(isOn ? tint : OtoUI.secondaryFG)
        }
        .buttonStyle(.plain)
        .help(helpText(for: f, isOn: isOn, action: action))
        .contextMenu {
            if let action {
                Button(action.menuLabel) { performBulkAction(action) }
                    .disabled(!action.isMeaningful(rules: state.store.rules))
            }
            Button("Show \(f.label.lowercased())") { filter = f }
        }
    }

    private func bulkAction(for f: RuleFilter) -> BulkAction? {
        switch f {
        case .active:   return .pauseAll
        case .inactive: return .resumeAll
        case .all:      return nil
        }
    }

    private func performBulkAction(_ action: BulkAction) {
        guard action.isMeaningful(rules: state.store.rules) else { return }
        switch action {
        case .pauseAll:  state.store.setAllRulesEnabled(false)
        case .resumeAll: state.store.setAllRulesEnabled(true)
        }
    }

    private func helpText(for f: RuleFilter, isOn: Bool, action: BulkAction?) -> String {
        if isOn, let action, action.isMeaningful(rules: state.store.rules) {
            return action.helpText
        }
        switch f {
        case .all:      return "Show all rules"
        case .active:   return "Show only enabled rules"
        case .inactive: return "Show only disabled rules"
        }
    }

    private func count(for f: RuleFilter) -> Int {
        switch f {
        case .all: return state.store.rules.count
        case .active: return state.store.rules.filter(\.enabled).count
        case .inactive: return state.store.rules.filter { !$0.enabled }.count
        }
    }
}

private struct QuietHoursStatusChip: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings

    @State private var refreshTick = Date()

    var body: some View {
        let settings = state.quietHours.settings
        let inWindow = settings.enabled && settings.isInWindow(now: refreshTick)
        let tint: Color = {
            if !settings.enabled       { return OtoUI.mutedFG }
            if inWindow                { return .otoTeal }
            return .otoNavy
        }()

        Button {
            state.quietHours.settings.enabled.toggle()
        } label: {
            HStack(spacing: 4) {
                OtoIcon(name: inWindow ? "moon.stars.fill" : "moon.stars", size: 10)
                Text("Quiet hours")
                    .font(.system(size: 10, weight: .medium))
                if inWindow {
                    Circle()
                        .fill(Color.otoTeal)
                        .frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                settings.enabled ? tint.opacity(0.16) : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        settings.enabled ? tint.opacity(0.40) : OtoUI.dividerColor,
                        lineWidth: 1
                    )
            }
            .foregroundStyle(settings.enabled ? tint : OtoUI.mutedFG)
        }
        .buttonStyle(.plain)
        .help(tooltip(settings: settings, inWindow: inWindow))
        .accessibilityLabel("Quiet hours")
        .accessibilityValue(accessibilityValueText(settings: settings, inWindow: inWindow))
        .accessibilityHint("Double-tap to toggle. Right-click to edit schedule.")
        .contextMenu {
            Button("Edit Schedule…") { openSettings() }
            Button(settings.enabled ? "Disable Quiet Hours" : "Enable Quiet Hours") {
                state.quietHours.settings.enabled.toggle()
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            refreshTick = now
        }
    }

    private func tooltip(settings: QuietHoursSettings, inWindow: Bool) -> String {
        if !settings.enabled {
            return "Quiet hours off — click to enable. Schedule and cap live in Settings."
        }
        let from = prettyTime(settings.startMinute)
        let to   = prettyTime(settings.endMinute)
        let cap  = Int(settings.maxVolume * 100)
        if inWindow {
            return "Quiet hours active — output capped at \(cap)% (\(from)–\(to)). Click to disable."
        }
        return "Quiet hours scheduled \(from)–\(to), cap \(cap)%. Click to disable."
    }

    private func accessibilityValueText(settings: QuietHoursSettings, inWindow: Bool) -> String {
        if !settings.enabled { return "off" }
        return inWindow ? "active, capping output now" : "scheduled, currently outside window"
    }

    private func prettyTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        var comps = DateComponents()
        comps.hour = h; comps.minute = m
        guard let date = Calendar.current.date(from: comps) else { return "\(h):\(m)" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#if DEBUG
#Preview("Spotlight — empty") {
    MainWindowView()
        .environment(AppState.previewEmpty)
        .frame(width: 712, height: 620)
}

#Preview("Spotlight — populated") {
    MainWindowView()
        .environment(AppState.previewPopulated)
        .frame(width: 712, height: 620)
}
#endif

#if DEBUG
private struct FilterTabsBarPreviewWrapper: View {
    @State private var filter: RuleFilter = .all
    var body: some View {
        FilterTabsBar(filter: $filter)
            .environment(AppState.previewPopulated)
            .padding(40)
            .background(Color.black.opacity(0.92))
            .preferredColorScheme(.dark)
    }
}

#Preview("Filter tabs bar") {
    FilterTabsBarPreviewWrapper()
}
#endif
