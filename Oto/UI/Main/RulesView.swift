import SwiftUI

// MARK: - RulesPanel

/// Material card containing the list of rule rows. Replaces the old
/// `RulesView` which lived inside a NavigationSplitView detail.
struct RulesPanel: View {
    @Environment(AppState.self) private var state
    let filter: RuleFilter
    let onEdit: (Rule) -> Void

    private let rowHeight: CGFloat = OtoUI.rowHeight
    private let panelInsets: CGFloat = 10
    private let visibleRowLimit = 5

    var filteredRules: [Rule] {
        switch filter {
        case .all: return state.store.rules
        case .active: return state.store.rules.filter(\.enabled)
        case .inactive: return state.store.rules.filter { !$0.enabled }
        }
    }

    /// Rule IDs that participate in a runtime conflict under the current
    /// active profile. Used to badge rows. Profile-aware so a Work-only
    /// duplicate doesn't get flagged while Home is active.
    private var conflictingIDs: Set<UUID> {
        RuleConflicts.conflictingRuleIDs(
            in: state.store.rules,
            activeProfileID: state.store.activeProfileID
        )
    }

    var body: some View {
        Group {
            if state.store.rules.isEmpty || filteredRules.isEmpty {
                emptyState
                    .frame(width: OtoUI.pillWidth)
                    .frame(minHeight: state.store.rules.isEmpty ? 320 : 188)
                    .materialPanel(strongShadow: false)
            } else {
                rulesList
                    .frame(width: OtoUI.pillWidth)
                    .frame(height: panelHeight)
                    .materialPanel(strongShadow: false)
            }
        }
    }

    private var panelHeight: CGFloat {
        let visible = min(max(filteredRules.count, 1), visibleRowLimit)
        return CGFloat(visible) * rowHeight + panelInsets * 2
    }

    private var rulesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filter == .all ? state.store.rules : filteredRules) { rule in
                    RuleRow(
                        rule: rule,
                        hasConflict: conflictingIDs.contains(rule.id),
                        onEdit: { onEdit(rule) }
                    )
                        .contextMenu {
                            Button("Edit") { onEdit(rule) }
                            Button("Duplicate") { state.store.duplicate(rule) }
                            Button(rule.enabled ? "Disable" : "Enable") { state.store.toggle(rule) }
                            Divider()
                            Button("Delete", role: .destructive) { state.store.delete(rule) }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, panelInsets)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(emptyStateTint.opacity(0.16))
                    .frame(width: 44, height: 44)
                    .blur(radius: 8)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(emptyStateTint.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(emptyStateTint.opacity(0.42), lineWidth: 1)
                    }
                OtoIcon(name: emptyStateIcon, size: 18, weight: .medium)
                    .foregroundStyle(emptyStateTint)
            }

            VStack(spacing: 4) {
                Text(emptyStateTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OtoUI.primaryFG)
                Text(emptyStateMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 460)
            }

            if let hint = emptyStateHint {
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(emptyStateTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(emptyStateTint.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(emptyStateTint.opacity(0.28), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 42)
        .padding(.vertical, 34)
    }

    private var emptyStateTitle: String {
        if state.store.rules.isEmpty { return "No rules yet" }
        switch filter {
        case .all: return "No rules yet"
        case .active: return "No active rules"
        case .inactive: return "No inactive rules"
        }
    }

    private var emptyStateMessage: String {
        if state.store.rules.isEmpty {
            return "Add a rule and Oto will switch your audio automatically when devices connect, apps launch, or your Mac wakes."
        }
        switch filter {
        case .all:
            return "Add a rule and Oto will start routing your audio automatically."
        case .active:
            return "Every rule is paused. Resume rules from the Inactive tab or add a new automation."
        case .inactive:
            return "All rules are currently active. Disabled rules will appear here when you pause one."
        }
    }

    private var emptyStateHint: String? {
        if state.store.rules.isEmpty { return "Use + in the header to add one" }
        switch filter {
        case .all: return "Use + in the header"
        case .active: return "Open Inactive to resume rules"
        case .inactive: return "Pause a rule to see it here"
        }
    }

    private var emptyStateIcon: String {
        if state.store.rules.isEmpty { return "wand.and.stars" }
        switch filter {
        case .all: return "wand.and.stars"
        case .active: return "pause.circle"
        case .inactive: return "checkmark.circle"
        }
    }

    private var emptyStateTint: Color {
        if state.store.rules.isEmpty { return .otoTeal }
        switch filter {
        case .all: return .otoTeal
        case .active: return .otoYellow
        case .inactive: return .otoTeal
        }
    }
}

// MARK: - RuleRow

struct RuleRow: View {
    @Environment(AppState.self) private var state
    let rule: Rule
    var hasConflict: Bool = false
    let onEdit: () -> Void

    @State private var isHovering = false

    private func resolvedName(uid: String, fallback: String) -> String {
        state.monitor.allDevices.first(where: { $0.uid == uid })?.name ?? fallback
    }

    private var triggerDisplayText: String {
        switch rule.trigger {
        case .deviceConnects(let uid, let name):
            return "When \(resolvedName(uid: uid, fallback: name)) connects"
        case .deviceDisconnects(let uid, let name):
            return "When \(resolvedName(uid: uid, fallback: name)) disconnects"
        case .anyBluetoothConnects, .systemWakes, .appLaunches:
            return rule.trigger.displayText
        }
    }

    private var actionDisplayText: String {
        switch rule.action {
        case .setInput(let uid, let name): return resolvedName(uid: uid, fallback: name)
        case .setOutput(let uid, let name): return resolvedName(uid: uid, fallback: name)
        case .setBoth(let inUID, let inName, let outUID, let outName):
            let i = resolvedName(uid: inUID, fallback: inName)
            let o = resolvedName(uid: outUID, fallback: outName)
            return i == o ? i : "\(i) + \(o)"
        default: return rule.action.displayText
        }
    }

    /// Color the icon tile takes — derived from the trigger device, with
    /// per-trigger fallbacks for the deviceless triggers.
    private var triggerTint: Color {
        switch rule.trigger {
        case .deviceConnects(let uid, let name),
             .deviceDisconnects(let uid, let name):
            if let d = state.monitor.allDevices.first(where: { $0.uid == uid }) {
                return d.displayTint
            }
            // Device not present right now — fall back on the name heuristic
            // so the row still gets a sensible color.
            let lower = name.lowercased()
            if lower.contains("yeti")     { return .otoAlert }
            if lower.contains("airpods")  { return .otoSage }
            if lower.contains("wh-") || lower.contains("headphone") { return .otoNavy }
            if lower.contains("fifine")   { return .otoTeal }
            return .otoTeal
        case .anyBluetoothConnects: return .otoNavy
        case .systemWakes:          return .otoYellow
        case .appLaunches:          return .otoSage
        }
    }

    /// Color the highlighted action-target text takes — uses the action's
    /// destination device if any, otherwise teal.
    private var actionTint: Color {
        switch rule.action {
        case .setInput(let uid, let name),
             .setOutput(let uid, let name),
             .setBoth(let uid, let name, _, _):
            if let d = state.monitor.allDevices.first(where: { $0.uid == uid }) {
                return d.displayTint
            }
            let lower = name.lowercased()
            if lower.contains("yeti")     { return .otoAlert }
            if lower.contains("airpods")  { return .otoSage }
            if lower.contains("macbook") || lower.contains("built-in") { return .otoYellow }
            if lower.contains("fifine")   { return .otoTeal }
            return .otoTeal
        case .setOutputVolume: return .otoYellow
        default: return .otoTeal
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            triggerTile

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(triggerDisplayText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if hasConflict && rule.enabled {
                        OtoIcon(name: "exclamationmark.triangle.fill", size: 11)
                            .foregroundStyle(Color.otoYellow)
                            .help("This rule conflicts with another rule. Only one will fire — open the editor to resolve.")
                            .accessibilityLabel("Conflict warning")
                    }
                }
                HStack(spacing: 4) {
                    OtoIcon(name: "arrow.right", size: 10)
                        .foregroundStyle(OtoUI.mutedFG)
                    if !rule.action.prefixText.isEmpty {
                        Text(rule.action.prefixText)
                            .foregroundStyle(OtoUI.mutedFG)
                    }
                    Text(actionDisplayText)
                        .foregroundStyle(rule.enabled ? actionTint : OtoUI.mutedFG)
                        .fontWeight(.medium)
                    if case .keepCurrent = rule.action {
                        Text("(do nothing)").foregroundStyle(OtoUI.mutedFG)
                    }
                }
                .font(.system(size: 12))
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { _ in state.store.toggle(rule) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(.otoTeal)

                // Combined "more" menu — Edit lives here so the standalone
                // gear button is gone (cleaner row, less visual noise).
                // Conditionally rendered (not just opacity-faded) so the
                // toggle slides into the freed space when the row isn't
                // hovered, instead of leaving a phantom gap.
                if isHovering {
                    IconButton(
                        icon: "ellipsis",
                        iconSize: 13,
                        help: "More",
                        action: {}
                    )
                    .overlay {
                        Menu {
                            Button("Edit", action: onEdit)
                            Button("Duplicate") { state.store.duplicate(rule) }
                            Button(rule.enabled ? "Disable" : "Enable") { state.store.toggle(rule) }
                            Divider()
                            Button("Delete", role: .destructive) { state.store.delete(rule) }
                        } label: {
                            Color.clear
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(.horizontal, isHovering ? 8 : 0)
        .frame(height: OtoUI.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: OtoUI.cardRadius, style: .continuous)
                .fill(isHovering ? OtoUI.rowSelected : Color.clear)
        }
        .contentShape(Rectangle())
        .opacity(rule.enabled ? 1.0 : 0.55)
        .onHover { isHovering = $0 }
        .animation(OtoUI.hoverEase, value: isHovering)
    }

    private var triggerTile: some View {
        let info = triggerIconInfo
        let tint = triggerTint
        return OtoIcon(name: info.icon, size: 20)
            .frame(width: OtoUI.triggerTileSize, height: OtoUI.triggerTileSize)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.32), lineWidth: 1)
            }
            .foregroundStyle(tint)
            .accessibilityHidden(true)
            .help(info.label)
    }

    private var triggerIconInfo: (icon: String, label: String) {
        switch rule.trigger {
        case .deviceConnects(let uid, let name):
            return tileFor(uid: uid, name: name, label: "Connect")
        case .deviceDisconnects(let uid, let name):
            return tileFor(uid: uid, name: name, label: "Disconnect")
        case .anyBluetoothConnects:
            return ("wave.3.right", "Bluetooth connects")
        case .systemWakes:
            return ("power", "System wakes")
        case .appLaunches:
            return ("app.dashed", "App launches")
        }
    }

    private func tileFor(uid: String, name: String, label: String) -> (icon: String, label: String) {
        if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
            return (device.kind.systemImage, label)
        }
        let lower = name.lowercased()
        if lower.contains("airpods") { return ("airpods", label) }
        if lower.contains("wh-") || lower.contains("headphone") { return ("headphones", label) }
        return ("mic", label)
    }
}

// MARK: - RuleEditorSheet

struct RuleEditorSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.otoDismiss) private var dismiss

    let existing: Rule?

    @State private var triggerKind: TriggerKind = .deviceConnects
    @State private var triggerDeviceUID: String = ""
    @State private var triggerDeviceName: String = ""
    @State private var triggerAppBundleID: String = ""
    @State private var triggerAppName: String = ""
    @State private var actionKind: ActionKind = .setInput
    @State private var inputDeviceUID: String = ""
    @State private var inputDeviceName: String = ""
    @State private var outputDeviceUID: String = ""
    @State private var outputDeviceName: String = ""
    @State private var volume: Double = 0.5
    @State private var outputVolume: Double = 0.4
    @State private var profileID: UUID? = nil
    @State private var conditionKind: ConditionKind = .none
    @State private var dryRunResult: RuleDryRunResult?

    enum TriggerKind: String, CaseIterable, Identifiable {
        case deviceConnects, deviceDisconnects, anyBluetooth, systemWakes, appLaunches
        var id: String { rawValue }
        var label: String {
            switch self {
            case .deviceConnects: return "When device connects"
            case .deviceDisconnects: return "When device disconnects"
            case .anyBluetooth: return "When any Bluetooth connects"
            case .systemWakes: return "When system wakes up"
            case .appLaunches: return "When app launches"
            }
        }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case setInput, setOutput, setBoth, setInputVolume, setOutputVolume, toggleInputMute, keepCurrent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .setInput: return "Set input to"
            case .setOutput: return "Set output to"
            case .setBoth: return "Set input + output"
            case .setInputVolume: return "Set input volume"
            case .setOutputVolume: return "Set output volume"
            case .toggleInputMute: return "Toggle input mute"
            case .keepCurrent: return "Keep current input"
            }
        }
    }

    /// UI-only enum that round-trips to `RuleCondition?`. The "none" case
    /// keeps the picker tidy — users see "No extra condition" as a first-
    /// class option rather than a disable-the-field-and-leave-it-blank UX.
    enum ConditionKind: String, CaseIterable, Identifiable {
        case none, headphonesNotConnected, headphonesConnected
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "No extra condition"
            case .headphonesNotConnected: return "Only when headphones aren't connected"
            case .headphonesConnected: return "Only when headphones are connected"
            }
        }
        var domain: RuleCondition? {
            switch self {
            case .none: return nil
            case .headphonesNotConnected: return .headphonesNotConnected
            case .headphonesConnected: return .headphonesConnected
            }
        }
        init(_ condition: RuleCondition?) {
            switch condition {
            case .none: self = .none
            case .headphonesNotConnected: self = .headphonesNotConnected
            case .headphonesConnected: self = .headphonesConnected
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "New rule" : "Edit rule")
                .font(.system(size: OtoUI.titleSize, weight: .semibold))

            rulePreviewCard

            if let warning = conflictWarning {
                conflictBanner(message: warning)
            }

            if let dryRunResult {
                dryRunBanner(dryRunResult)
            }

            VStack(spacing: 0) {
                FormRow(label: "Trigger") {
                    Picker("", selection: $triggerKind) {
                        ForEach(TriggerKind.allCases) { k in Text(k.label).tag(k) }
                    }
                    .labelsHidden()
                }

                if triggerKind == .deviceConnects || triggerKind == .deviceDisconnects {
                    FormRow(label: "Device") {
                        Picker("", selection: $triggerDeviceUID) {
                            Text("Select device").tag("")
                            ForEach(state.monitor.allDevices, id: \.uid) { d in
                                Text(d.name).tag(d.uid)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: triggerDeviceUID) { _, newValue in
                            triggerDeviceName = state.monitor.allDevices.first(where: { $0.uid == newValue })?.name ?? triggerDeviceName
                        }
                    }
                }

                if triggerKind == .appLaunches {
                    FormRow(label: "App") {
                        appPicker
                    }
                }

                FormRow(label: "Action") {
                    Picker("", selection: $actionKind) {
                        ForEach(ActionKind.allCases) { k in Text(k.label).tag(k) }
                    }
                    .labelsHidden()
                }

                switch actionKind {
                case .setInput:
                    inputPicker
                case .setOutput:
                    outputPicker
                case .setBoth:
                    inputPicker
                    outputPicker
                case .setInputVolume:
                    FormRow(label: "Volume") {
                        HStack {
                            Slider(value: $volume, in: 0...1)
                            Text("\(Int(volume * 100))%")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                                .foregroundStyle(OtoUI.mutedFG)
                        }
                    }
                case .setOutputVolume:
                    FormRow(label: "Volume") {
                        HStack {
                            Slider(value: $outputVolume, in: 0...1)
                            Text("\(Int(outputVolume * 100))%")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                                .foregroundStyle(OtoUI.mutedFG)
                        }
                    }
                case .toggleInputMute, .keepCurrent:
                    EmptyView()
                }

                FormRow(label: "Condition") {
                    Picker("", selection: $conditionKind) {
                        ForEach(ConditionKind.allCases) { c in Text(c.label).tag(c) }
                    }
                    .labelsHidden()
                }

                FormRow(label: "Profile", isLast: true) {
                    Picker("", selection: $profileID) {
                        Text("Always active").tag(Optional<UUID>.none)
                        ForEach(state.store.profiles) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack {
                Button("Dry Run") {
                    performDryRun()
                }
                .buttonStyle(.plain)
                .foregroundStyle(isValid ? Color.otoTeal : OtoUI.mutedFG)
                .disabled(!isValid)

                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(OtoUI.secondaryFG)
                Button(existing == nil ? "Add" : "Save") {
                    if let rule = buildRule() {
                        if existing == nil {
                            state.store.add(rule)
                        } else {
                            state.store.update(rule)
                        }
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.otoTeal)
                .disabled(!isValid)
            }
        }
        .padding(26)
        .frame(width: 520)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .onAppear(perform: hydrate)
        .onChange(of: triggerKind) { _, _ in dryRunResult = nil }
        .onChange(of: triggerDeviceUID) { _, _ in dryRunResult = nil }
        .onChange(of: triggerAppBundleID) { _, _ in dryRunResult = nil }
        .onChange(of: actionKind) { _, _ in dryRunResult = nil }
        .onChange(of: inputDeviceUID) { _, _ in dryRunResult = nil }
        .onChange(of: outputDeviceUID) { _, _ in dryRunResult = nil }
        .onChange(of: conditionKind) { _, _ in dryRunResult = nil }
        .onChange(of: profileID) { _, _ in dryRunResult = nil }
    }

    private var rulePreviewCard: some View {
        HStack(alignment: .top, spacing: 10) {
            OtoIcon(name: "text.quote", size: 14)
                .foregroundStyle(Color.otoTeal)
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                Text(previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                .strokeBorder(OtoUI.strokeColor.opacity(0.5), lineWidth: 1)
        }
    }

    /// Picker that fuses two sources: well-known apps (always visible so
    /// you can wire up Spotify even before launching it once this session)
    /// and currently-running apps (so the UID and display name come from
    /// the live `NSRunningApplication`). Duplicates collapse on bundleID.
    @ViewBuilder
    private var appPicker: some View {
        Picker("", selection: $triggerAppBundleID) {
            Text("Select app").tag("")

            let combined: [LaunchedApp] = {
                var seen = Set<String>()
                var out: [LaunchedApp] = []
                for app in WellKnownApps.suggestions + state.appLaunchMonitor.runningApps {
                    if seen.insert(app.bundleID).inserted { out.append(app) }
                }
                return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }()

            ForEach(combined) { app in
                Text(app.name).tag(app.bundleID)
            }
        }
        .labelsHidden()
        .onChange(of: triggerAppBundleID) { _, newValue in
            // Refresh the cached display name from whichever source the
            // user just picked. If the bundleID isn't currently running and
            // isn't in the curated list, fall back to whatever name was
            // already cached (covers the edit-existing-rule path).
            let combined = WellKnownApps.suggestions + state.appLaunchMonitor.runningApps
            triggerAppName = combined.first(where: { $0.bundleID == newValue })?.name ?? triggerAppName
        }
    }

    @ViewBuilder
    private var inputPicker: some View {
        FormRow(label: "Input") {
            Picker("", selection: $inputDeviceUID) {
                Text("Select input").tag("")
                ForEach(state.inputDevices, id: \.uid) { d in
                    Text(d.name).tag(d.uid)
                }
            }
            .labelsHidden()
            .onChange(of: inputDeviceUID) { _, newValue in
                inputDeviceName = state.inputDevices.first(where: { $0.uid == newValue })?.name ?? inputDeviceName
            }
        }
    }

    @ViewBuilder
    private var outputPicker: some View {
        FormRow(label: "Output") {
            Picker("", selection: $outputDeviceUID) {
                Text("Select output").tag("")
                ForEach(state.monitor.allDevices.filter(\.hasOutput), id: \.uid) { d in
                    Text(d.name).tag(d.uid)
                }
            }
            .labelsHidden()
            .onChange(of: outputDeviceUID) { _, newValue in
                outputDeviceName = state.monitor.allDevices.first(where: { $0.uid == newValue })?.name ?? outputDeviceName
            }
        }
    }

    private func hydrate() {
        guard let r = existing else { return }
        profileID = r.profileID
        conditionKind = ConditionKind(r.condition)
        switch r.trigger {
        case .deviceConnects(let uid, let name):
            triggerKind = .deviceConnects
            triggerDeviceUID = uid; triggerDeviceName = name
        case .deviceDisconnects(let uid, let name):
            triggerKind = .deviceDisconnects
            triggerDeviceUID = uid; triggerDeviceName = name
        case .anyBluetoothConnects: triggerKind = .anyBluetooth
        case .systemWakes: triggerKind = .systemWakes
        case .appLaunches(let bundleID, let name):
            triggerKind = .appLaunches
            triggerAppBundleID = bundleID; triggerAppName = name
        }
        switch r.action {
        case .setInput(let uid, let name):
            actionKind = .setInput; inputDeviceUID = uid; inputDeviceName = name
        case .setOutput(let uid, let name):
            actionKind = .setOutput; outputDeviceUID = uid; outputDeviceName = name
        case .setBoth(let iu, let iN, let ou, let oN):
            actionKind = .setBoth
            inputDeviceUID = iu; inputDeviceName = iN
            outputDeviceUID = ou; outputDeviceName = oN
        case .setInputVolume(let v):
            actionKind = .setInputVolume; volume = v
        case .setOutputVolume(let v):
            actionKind = .setOutputVolume; outputVolume = v
        case .toggleInputMute: actionKind = .toggleInputMute
        case .keepCurrent: actionKind = .keepCurrent
        }
    }

    private var isValid: Bool {
        switch triggerKind {
        case .deviceConnects, .deviceDisconnects:
            if triggerDeviceUID.isEmpty { return false }
        case .appLaunches:
            if triggerAppBundleID.isEmpty { return false }
        case .anyBluetooth, .systemWakes: break
        }
        switch actionKind {
        case .setInput: if inputDeviceUID.isEmpty { return false }
        case .setOutput: if outputDeviceUID.isEmpty { return false }
        case .setBoth:
            if inputDeviceUID.isEmpty || outputDeviceUID.isEmpty { return false }
        case .setInputVolume, .setOutputVolume, .toggleInputMute, .keepCurrent: break
        }
        return true
    }

    /// Re-evaluates conflicts as the user edits the form. Returns the
    /// human-readable message shown in the banner, or nil when there's no
    /// conflict (or when the form isn't yet valid enough to construct a
    /// hypothetical rule).
    private var conflictWarning: String? {
        guard isValid, let candidate = buildRule() else { return nil }
        // Build the "what the rules array would look like after Save" set —
        // replacing the existing rule by id, or appending the candidate.
        var hypothetical = state.store.rules
        if let idx = hypothetical.firstIndex(where: { $0.id == candidate.id }) {
            hypothetical[idx] = candidate
        } else {
            hypothetical.append(candidate)
        }
        let clusters = RuleConflicts.clusters(in: hypothetical, activeProfileID: profileID)
        // Filter to clusters that actually include the candidate. If the
        // candidate isn't part of any cluster, it isn't *introducing* a
        // conflict — don't nag the user about pre-existing ones.
        guard let cluster = clusters.first(where: { $0.ruleIDs.contains(candidate.id) }) else {
            return nil
        }
        return cluster.explanation
    }

    private func conflictBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            OtoIcon(name: "exclamationmark.triangle.fill", size: 14)
                .foregroundStyle(Color.otoYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Possible conflict")
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.otoYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                .strokeBorder(Color.otoYellow.opacity(0.35), lineWidth: 1)
        }
    }

    private func dryRunBanner(_ result: RuleDryRunResult) -> some View {
        let tint: Color = result.isPositive ? .otoTeal : (result.outcome == .targetMissing || result.outcome == .invalid || result.outcome == .conflict ? .otoAlert : .otoYellow)
        return HStack(alignment: .top, spacing: 10) {
            OtoIcon(name: result.isPositive ? "checkmark.circle.fill" : "info.circle.fill", size: 14)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(result.message)
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        }
    }

    private var previewText: String {
        "\(triggerPreview), \(actionPreview)\(conditionPreview)\(profilePreview)."
    }

    private var triggerPreview: String {
        switch triggerKind {
        case .deviceConnects:
            return "When \(selectedTriggerDeviceName) connects"
        case .deviceDisconnects:
            return "When \(selectedTriggerDeviceName) disconnects"
        case .anyBluetooth:
            return "When any Bluetooth device connects"
        case .systemWakes:
            return "When system wakes up"
        case .appLaunches:
            return "When \(selectedAppName) launches"
        }
    }

    private var actionPreview: String {
        switch actionKind {
        case .setInput:
            return "set input to \(selectedInputName)"
        case .setOutput:
            return "set output to \(selectedOutputName)"
        case .setBoth:
            return "set input to \(selectedInputName) and output to \(selectedOutputName)"
        case .setInputVolume:
            return "set input volume to \(Int(volume * 100))%"
        case .setOutputVolume:
            return "set output volume to \(Int(outputVolume * 100))%"
        case .toggleInputMute:
            return "toggle input mute"
        case .keepCurrent:
            return "keep the current input"
        }
    }

    private var conditionPreview: String {
        conditionKind.domain.map { ", \(lowercasedLeading($0.displayText))" } ?? ""
    }

    private var profilePreview: String {
        guard let profileID,
              let profile = state.store.profiles.first(where: { $0.id == profileID }) else { return "" }
        return ", in the \(profile.name) profile"
    }

    private var selectedTriggerDeviceName: String {
        state.monitor.allDevices.first(where: { $0.uid == triggerDeviceUID })?.name ?? (triggerDeviceName.isEmpty ? "a device" : triggerDeviceName)
    }

    private var selectedAppName: String {
        let combined = WellKnownApps.suggestions + state.appLaunchMonitor.runningApps
        return combined.first(where: { $0.bundleID == triggerAppBundleID })?.name ?? (triggerAppName.isEmpty ? "an app" : triggerAppName)
    }

    private var selectedInputName: String {
        state.inputDevices.first(where: { $0.uid == inputDeviceUID })?.name ?? (inputDeviceName.isEmpty ? "an input" : inputDeviceName)
    }

    private var selectedOutputName: String {
        state.monitor.allDevices.first(where: { $0.uid == outputDeviceUID })?.name ?? (outputDeviceName.isEmpty ? "an output" : outputDeviceName)
    }

    private func lowercasedLeading(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    private func performDryRun() {
        guard let rule = buildRule() else { return }
        var result = RuleDryRunner.evaluate(rule: rule, monitor: state.monitor, store: state.store)
        if let warning = conflictWarning, result.outcome == .wouldApply {
            result = RuleDryRunResult(
                outcome: .conflict,
                title: "Conflict possible",
                message: warning,
                targetName: rule.action.displayText
            )
        }
        dryRunResult = result
        state.store.recordFire(
            rule: rule,
            deviceName: result.targetName,
            outcome: result.outcome.historyOutcome,
            resultSummary: result.message,
            isDryRun: true
        )
    }

    private func buildRule() -> Rule? {
        let trigger: RuleTrigger
        switch triggerKind {
        case .deviceConnects:
            let name = state.monitor.allDevices.first(where: { $0.uid == triggerDeviceUID })?.name ?? triggerDeviceName
            trigger = .deviceConnects(deviceUID: triggerDeviceUID, deviceName: name)
        case .deviceDisconnects:
            let name = state.monitor.allDevices.first(where: { $0.uid == triggerDeviceUID })?.name ?? triggerDeviceName
            trigger = .deviceDisconnects(deviceUID: triggerDeviceUID, deviceName: name)
        case .anyBluetooth: trigger = .anyBluetoothConnects
        case .systemWakes: trigger = .systemWakes
        case .appLaunches:
            let combined = WellKnownApps.suggestions + state.appLaunchMonitor.runningApps
            let name = combined.first(where: { $0.bundleID == triggerAppBundleID })?.name ?? triggerAppName
            trigger = .appLaunches(bundleID: triggerAppBundleID, appName: name)
        }
        let action: RuleAction
        switch actionKind {
        case .setInput:
            let name = state.inputDevices.first(where: { $0.uid == inputDeviceUID })?.name ?? inputDeviceName
            action = .setInput(deviceUID: inputDeviceUID, deviceName: name)
        case .setOutput:
            let name = state.monitor.allDevices.first(where: { $0.uid == outputDeviceUID })?.name ?? outputDeviceName
            action = .setOutput(deviceUID: outputDeviceUID, deviceName: name)
        case .setBoth:
            let inName = state.inputDevices.first(where: { $0.uid == inputDeviceUID })?.name ?? inputDeviceName
            let outName = state.monitor.allDevices.first(where: { $0.uid == outputDeviceUID })?.name ?? outputDeviceName
            action = .setBoth(inputUID: inputDeviceUID, inputName: inName, outputUID: outputDeviceUID, outputName: outName)
        case .setInputVolume:
            action = .setInputVolume(volume: volume)
        case .setOutputVolume:
            action = .setOutputVolume(volume: outputVolume)
        case .toggleInputMute:
            action = .toggleInputMute
        case .keepCurrent:
            action = .keepCurrent
        }
        if let r = existing {
            return Rule(
                id: r.id,
                trigger: trigger,
                action: action,
                enabled: r.enabled,
                profileID: profileID,
                condition: conditionKind.domain
            )
        }
        return Rule(
            trigger: trigger,
            action: action,
            profileID: profileID,
            condition: conditionKind.domain
        )
    }
}

// MARK: - FormRow

/// Custom row replacing `.formStyle(.grouped)` so sheets match the dark
/// material aesthetic. Label flush left, control flush right.
struct FormRow<Content: View>: View {
    let label: String
    var isLast: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
                    .frame(width: 88, alignment: .leading)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            if !isLast {
                Rectangle()
                    .fill(OtoUI.dividerColor)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - TemplatesSheet

struct TemplatesSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.otoDismiss) private var dismiss

    @State private var selected: Set<UUID> = []

    var templates: [RuleTemplates.Suggestion] {
        RuleTemplates.suggestions(for: state.monitor.allDevices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rule templates")
                    .font(.system(size: OtoUI.titleSize, weight: .semibold))
                Text("Suggestions based on your connected devices.")
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
            }

            if templates.isEmpty {
                Text("No suggestions available. Connect some audio devices first.")
                    .foregroundStyle(OtoUI.mutedFG)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(templates) { t in
                            templateRow(t)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(OtoUI.secondaryFG)
                Button("Add Selected") {
                    for t in templates where selected.contains(t.id) {
                        for r in t.rules { state.store.add(r) }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.otoTeal)
                .disabled(selected.isEmpty)
            }
        }
        .padding(26)
        .frame(width: 560)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }

    private func templateRow(_ t: RuleTemplates.Suggestion) -> some View {
        let isOn = selected.contains(t.id)
        return Button {
            // Read selection inside the closure so the toggle always reflects
            // the current state — capturing `isOn` at build time worked in
            // theory but proved flaky inside ScrollView/LazyVStack where
            // SwiftUI sometimes reused stale closures.
            if selected.contains(t.id) {
                selected.remove(t.id)
            } else {
                selected.insert(t.id)
            }
        } label: {
            HStack(spacing: 12) {
                OtoIcon(name: isOn ? "checkmark.circle.fill" : "circle", size: 18)
                    .foregroundStyle(isOn ? Color.otoTeal : OtoUI.mutedFG)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(.system(size: 14, weight: .medium))
                    Text(t.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(OtoUI.mutedFG)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                    .strokeBorder(isOn ? Color.otoTeal.opacity(0.4) : OtoUI.strokeColor.opacity(0.5), lineWidth: 1)
            }
            // Make the entire pill (including the spacer area) the hit target.
            .contentShape(RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Rule row — enabled") {
    RuleRow(rule: Rule.previewSamples[0], onEdit: {})
        .environment(AppState.previewPopulated)
        .frame(width: OtoUI.pillWidth - 24)
        .padding(20)
        .background(Color.black.opacity(0.92))
        .preferredColorScheme(.dark)
}

#Preview("Rule row — with conflict") {
    RuleRow(rule: Rule.previewSamples[0], hasConflict: true, onEdit: {})
        .environment(AppState.previewPopulated)
        .frame(width: OtoUI.pillWidth - 24)
        .padding(20)
        .background(Color.black.opacity(0.92))
        .preferredColorScheme(.dark)
}

#Preview("Rules panel — populated") {
    RulesPanel(filter: .all, onEdit: { _ in })
        .environment(AppState.previewPopulated)
        .padding(40)
        .background(Color.black.opacity(0.92))
        .preferredColorScheme(.dark)
}

#Preview("Rules panel — empty") {
    RulesPanel(filter: .all, onEdit: { _ in })
        .environment(AppState.previewEmpty)
        .padding(40)
        .background(Color.black.opacity(0.92))
        .preferredColorScheme(.dark)
}

#Preview("Rule editor — new") {
    RuleEditorSheet(existing: nil)
        .environment(AppState.previewPopulated)
        .previewSheetBackdrop()
}

#Preview("Rule editor — edit") {
    RuleEditorSheet(existing: Rule.previewSamples[0])
        .environment(AppState.previewPopulated)
        .previewSheetBackdrop()
}

#Preview("Templates sheet") {
    TemplatesSheet()
        .environment(AppState.previewPopulated)
        .previewSheetBackdrop()
}
#endif
