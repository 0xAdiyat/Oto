import Combine
import SwiftUI

/// Spotlight-style root view: borderless transparent window contents.
/// Header pill on top, filter bar, then the rules panel — staggered entrance
/// animation matches media-downloader's ContentView reveal.
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

            VStack(spacing: 14) {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 56)
            .padding(.bottom, 56)

            // In-panel sheet overlay. Replaces SwiftUI's `.sheet` modifier
            // because the system sheet on a borderless transparent NSPanel
            // applies a hard-edged rectangular dim to the parent that
            // doesn't conform to the panel's rounded corners — visually
            // broken. Rendering as a sibling in the ZStack keeps the dim
            // inside the panel and inherits its rounded mask via the
            // window's existing transparent shape.
            if isSheetActive {
                sheetOverlay
                    .transition(.opacity)
            }

            // Hidden ⌘Z / ⇧⌘Z carriers. We register them as zero-frame
            // siblings of the main content rather than inside `.background`:
            // putting NSButton-bridged controls in a `.background` causes
            // AppKit's layout system to re-measure them mid-parent-layout
            // every time `canUndo` / `canRedo` flips, which trips
            // `_NSDetectedLayoutRecursion`. As true ZStack siblings with a
            // zero frame and `.hidden()`, they stay in the responder chain
            // (so the keyboard shortcut works) without participating in any
            // layout that the rest of the panel is doing.
            UndoCommandCarriers()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        // Single animation scoped to the overlay's appearance / dismissal.
        // Tying it to `isSheetActive` (a derived Bool) instead of either
        // raw `sheet` or `editingRule` means a transition between the two
        // sheet states (rare — only happens if user opens an editor for a
        // rule directly via context menu while another sheet is up) won't
        // re-fire the animation needlessly.
        .animation(.easeOut(duration: 0.18), value: isSheetActive)
        .onAppear { runRevealAnimation() }
        // Re-run the reveal exactly when the window is brought back on screen
        // (orderOut → makeKeyAndOrderFront). Tying this to anything broader —
        // NSApp.didBecomeActive, didResignActive — caused the panel to vanish
        // on transient focus changes (e.g. clicking a filter tab triggered a
        // brief app deactivation in the borderless window, which wiped the
        // entrance state without a follow-up activate to restore it).
        .onReceive(NotificationCenter.default.publisher(for: .spotlightWindowDidPresent)) { _ in
            runRevealAnimation()
        }
    }

    // MARK: - Sheet overlay

    private var isSheetActive: Bool {
        sheet != nil || editingRule != nil
    }

    @ViewBuilder
    private var sheetOverlay: some View {
        ZStack {
            // No-tint backdrop. The sheet panels carry their own
            // `.materialPanel()` chrome (frosted material + shadow + stroke)
            // so visual separation is already built-in — adding a parent
            // dim on top of that double-darkened the panel and produced
            // the awkward rectangular tint the user saw.
            //
            // `Color.clear` still participates in hit-testing in SwiftUI,
            // so click-outside-to-dismiss continues to work without any
            // visual cost.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismissActiveSheet() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Dismiss")

            // Active sheet content. Two-axis transition (scale + opacity)
            // matches macOS sheet entry feel without dragging in any
            // bridged AppKit chrome.
            currentSheetContent
                .transition(.scale(scale: 0.96).combined(with: .opacity))

            // Escape-to-dismiss. Hidden zero-frame Button purely as a
            // keyboard shortcut sink — same rationale as UndoCommandCarriers
            // (kept out of `.background` to dodge layout recursion).
            Button("Cancel") { dismissActiveSheet() }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        // Inject our closure-based dismiss into the environment so each
        // sheet view's `@Environment(\.otoDismiss) dismiss` resolves to
        // *this* presenter's tear-down path, regardless of which case in
        // `ActiveSheet` (or `editingRule`) is currently up.
        .environment(\.otoDismiss, OtoDismissAction(action: dismissActiveSheet))
    }

    @ViewBuilder
    private var currentSheetContent: some View {
        // editingRule wins over `sheet` if both are somehow set — neither
        // path normally produces that state, but defensive ordering keeps
        // a stale `sheet` from preempting an active edit.
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
        // Clear whichever drove the overlay open. editingRule has priority
        // (matches `currentSheetContent`'s evaluation order) so user expectation
        // — "the thing on top is what closes" — holds even if both are non-nil.
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

/// Standalone view housing the hidden Undo / Redo buttons. Extracted so it
/// owns its own SwiftUI invalidation scope: when `canUndo` / `canRedo`
/// flips, only this tiny zero-frame view re-evaluates, not the whole
/// MainWindowView body. That isolation is what keeps the AppKit layout
/// engine from seeing repeated NSButton remeasurements during a parent
/// layout pass (the source of `_NSDetectedLayoutRecursion`).
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

// MARK: - Filter

enum RuleFilter: String, CaseIterable, Identifiable {
    case all, active, inactive
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Each tab gets its own brand color when selected so the active filter
    /// is identifiable at a glance — teal for the catch-all view, yellow for
    /// "live" rules, alert-red for disabled ones.
    var tint: Color {
        switch self {
        case .all:      return .otoTeal
        case .active:   return .otoYellow
        case .inactive: return .otoAlert
        }
    }
}

/// Secondary action attached to a selected filter chip. The chip's primary
/// click still filters; this fires on the *second* click of an already-
/// selected chip, and is also exposed via the chip's context menu.
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

    /// True when the action would actually change something — used to
    /// disable the menu item and skip a redundant store mutation when, say,
    /// the user clicks "Resume All" but everything is already enabled.
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
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
            }
            QuietHoursStatusChip()
        }
        .frame(width: OtoUI.pillWidth)
        .padding(.horizontal, 4)
        // Drives both the chip-selected highlight and the action-hint icon
        // transition. Tied to `filter` (not the rule list) so adding /
        // removing a rule doesn't ripple a chip animation.
        .animation(.easeOut(duration: 0.14), value: filter)
    }

    /// Single filter pill. Two interaction modes:
    /// - First click (chip not selected): selects the filter — the
    ///   long-standing behaviour, unchanged.
    /// - Second click (chip already selected) on `.active` or `.inactive`:
    ///   performs the bulk pause/resume action that name implies. The
    ///   secondary action is hinted with a small play/pause icon that only
    ///   appears on the currently-selected actionable chip, so users
    ///   discover the gesture without it getting in the way of the primary
    ///   filter affordance.
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
            HStack(spacing: 6) {
                Text(f.label)
                    .font(.system(size: 12, weight: .medium))
                Text("\(count(for: f))")
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(isOn ? tint.opacity(0.18) : OtoUI.rowIdle, in: Capsule())
                if showActionHint, let icon = action?.iconName {
                    OtoIcon(name: icon, size: 9)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isOn ? tint.opacity(0.18) : Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? tint.opacity(0.45) : OtoUI.dividerColor, lineWidth: 1)
            }
            .foregroundStyle(isOn ? tint : OtoUI.secondaryFG)
        }
        .buttonStyle(.plain)
        .help(helpText(for: f, isOn: isOn, action: action))
        // Right-click as an alternate path to the same bulk action — the
        // primary chip click can still be "I just want to filter," and the
        // power user has a dedicated secondary control in the context menu.
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

// MARK: - Quiet Hours chip

/// Compact toggle + status indicator for the global Quiet Hours guardrail.
/// Lives in the filter bar so users can flip the cap on/off mid-session
/// without opening Settings — useful when you're playing music *and* on a
/// late-night call where the cap would clip the call audio.
///
/// States read at a glance:
///   • Disabled                — outline, muted moon
///   • Enabled, outside window — outline, navy moon, "starts at" tooltip
///   • Enabled, inside window  — solid teal, dot indicator, "active" tooltip
private struct QuietHoursStatusChip: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings

    /// Refresh tick so the "outside window → inside window" transition
    /// doesn't require a manual nudge. 60 s is good enough for a humans-
    /// reading-a-pill use case; it aligns with the QuietHoursManager's
    /// own tick cadence.
    @State private var refreshTick = Date()

    var body: some View {
        let settings = state.quietHours.settings
        let inWindow = settings.enabled && settings.isInWindow(now: refreshTick)
        let tint: Color = {
            if !settings.enabled       { return OtoUI.mutedFG }
            if inWindow                { return .otoTeal }
            return .otoNavy
        }()
        let label: String = {
            if !settings.enabled { return "Quiet hours" }
            if inWindow          { return "Quiet hours" }
            return "Quiet hours"
        }()

        Button {
            state.quietHours.settings.enabled.toggle()
        } label: {
            HStack(spacing: 5) {
                OtoIcon(name: inWindow ? "moon.stars.fill" : "moon.stars", size: 11)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                if inWindow {
                    Circle()
                        .fill(Color.otoTeal)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
        // Drive the in-window check off a slow timer so a window edge
        // (e.g. crossing into 01:00) repaints without a click. The
        // QuietHoursManager already polls every 30 s; this one is purely
        // visual and runs at 60 s to match human scanning cadence.
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
