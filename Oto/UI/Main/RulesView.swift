import SwiftUI

// MARK: - RulesPanel

/// Material card containing the list of rule rows. Replaces the old
/// `RulesView` which lived inside a NavigationSplitView detail.
struct RulesPanel: View {
    @Environment(AppState.self) private var state
    let filter: RuleFilter
    let onEdit: (Rule) -> Void

    private let rowHeight: CGFloat = 78
    private let panelInsets: CGFloat = 10
    private let visibleRowLimit = 5

    var filteredRules: [Rule] {
        switch filter {
        case .all: return state.store.rules
        case .active: return state.store.rules.filter(\.enabled)
        case .inactive: return state.store.rules.filter { !$0.enabled }
        }
    }

    var body: some View {
        Group {
            if state.store.rules.isEmpty {
                emptyState
                    .frame(width: OtoUI.pillWidth)
                    .frame(minHeight: 320)
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
                    RuleRow(rule: rule, onEdit: { onEdit(rule) })
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
        VStack(spacing: 14) {
            OtoIcon(name: "list-checks", size: 36)
                .foregroundStyle(OtoUI.mutedFG)
            Text("No rules yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Add a rule and Oto will switch your input automatically when devices connect, disconnect, or your Mac wakes.")
                .font(.system(size: 13))
                .foregroundStyle(OtoUI.mutedFG)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Text("Use the + button in the header to add one.")
                .font(.system(size: 12))
                .foregroundStyle(OtoUI.mutedFG)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - RuleRow

struct RuleRow: View {
    @Environment(AppState.self) private var state
    let rule: Rule
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
        case .anyBluetoothConnects, .systemWakes:
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

    var body: some View {
        HStack(spacing: 14) {
            triggerTile

            VStack(alignment: .leading, spacing: 3) {
                Text(triggerDisplayText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    OtoIcon(name: "arrow-right", size: 10)
                        .foregroundStyle(OtoUI.mutedFG)
                    if !rule.action.prefixText.isEmpty {
                        Text(rule.action.prefixText)
                            .foregroundStyle(OtoUI.mutedFG)
                    }
                    Text(actionDisplayText)
                        .foregroundStyle(rule.enabled ? Color.otoTeal : OtoUI.mutedFG)
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

                IconButton(icon: "settings", iconSize: 13, help: "Edit", action: onEdit)

                IconButton(
                    icon: "ellipsis",
                    iconSize: 13,
                    help: "More",
                    action: {}
                )
                .overlay {
                    // Use a Menu underneath to give the icon button a real menu.
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
            }
            .opacity(isHovering ? 1 : 0.72)
        }
        .padding(.horizontal, 10)
        .frame(height: 70)
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
        return OtoIcon(name: info.icon, size: 20)
            .frame(width: OtoUI.triggerTileSize, height: OtoUI.triggerTileSize)
            .background(OtoUI.iconTile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(OtoUI.strokeColor.opacity(0.6), lineWidth: 1)
            }
            .foregroundStyle(.primary.opacity(0.85))
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
            return ("bluetooth", "Bluetooth connects")
        case .systemWakes:
            return ("power", "System wakes")
        }
    }

    private func tileFor(uid: String, name: String, label: String) -> (icon: String, label: String) {
        if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
            return (device.kind.systemImage, label)
        }
        let lower = name.lowercased()
        if lower.contains("airpods") { return ("ear", label) }
        if lower.contains("wh-") || lower.contains("headphone") { return ("headphones", label) }
        return ("mic", label)
    }
}

// MARK: - RuleEditorSheet

struct RuleEditorSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    let existing: Rule?

    @State private var triggerKind: TriggerKind = .deviceConnects
    @State private var triggerDeviceUID: String = ""
    @State private var triggerDeviceName: String = ""
    @State private var actionKind: ActionKind = .setInput
    @State private var inputDeviceUID: String = ""
    @State private var inputDeviceName: String = ""
    @State private var outputDeviceUID: String = ""
    @State private var outputDeviceName: String = ""
    @State private var volume: Double = 0.5
    @State private var profileID: UUID? = nil

    enum TriggerKind: String, CaseIterable, Identifiable {
        case deviceConnects, deviceDisconnects, anyBluetooth, systemWakes
        var id: String { rawValue }
        var label: String {
            switch self {
            case .deviceConnects: return "When device connects"
            case .deviceDisconnects: return "When device disconnects"
            case .anyBluetooth: return "When any Bluetooth connects"
            case .systemWakes: return "When system wakes up"
            }
        }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case setInput, setOutput, setBoth, setInputVolume, toggleInputMute, keepCurrent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .setInput: return "Set input to"
            case .setOutput: return "Set output to"
            case .setBoth: return "Set input + output"
            case .setInputVolume: return "Set input volume"
            case .toggleInputMute: return "Toggle input mute"
            case .keepCurrent: return "Keep current input"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "New rule" : "Edit rule")
                .font(.system(size: OtoUI.titleSize, weight: .semibold))

            VStack(spacing: 0) {
                FormRow(label: "Trigger") {
                    Picker("", selection: $triggerKind) {
                        ForEach(TriggerKind.allCases) { k in Text(k.label).tag(k) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                case .toggleInputMute, .keepCurrent:
                    EmptyView()
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
        .preferredColorScheme(.light)
        .onAppear(perform: hydrate)
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
        switch r.trigger {
        case .deviceConnects(let uid, let name):
            triggerKind = .deviceConnects
            triggerDeviceUID = uid; triggerDeviceName = name
        case .deviceDisconnects(let uid, let name):
            triggerKind = .deviceDisconnects
            triggerDeviceUID = uid; triggerDeviceName = name
        case .anyBluetoothConnects: triggerKind = .anyBluetooth
        case .systemWakes: triggerKind = .systemWakes
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
        case .toggleInputMute: actionKind = .toggleInputMute
        case .keepCurrent: actionKind = .keepCurrent
        }
    }

    private var isValid: Bool {
        switch triggerKind {
        case .deviceConnects, .deviceDisconnects:
            if triggerDeviceUID.isEmpty { return false }
        case .anyBluetooth, .systemWakes: break
        }
        switch actionKind {
        case .setInput: if inputDeviceUID.isEmpty { return false }
        case .setOutput: if outputDeviceUID.isEmpty { return false }
        case .setBoth:
            if inputDeviceUID.isEmpty || outputDeviceUID.isEmpty { return false }
        case .setInputVolume, .toggleInputMute, .keepCurrent: break
        }
        return true
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
        case .toggleInputMute:
            action = .toggleInputMute
        case .keepCurrent:
            action = .keepCurrent
        }
        if let r = existing {
            return Rule(id: r.id, trigger: trigger, action: action, enabled: r.enabled, profileID: profileID)
        }
        return Rule(trigger: trigger, action: action, profileID: profileID)
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
    @Environment(\.dismiss) private var dismiss

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
        .preferredColorScheme(.light)
    }

    private func templateRow(_ t: RuleTemplates.Suggestion) -> some View {
        let isOn = selected.contains(t.id)
        return Button {
            if isOn { selected.remove(t.id) } else { selected.insert(t.id) }
        } label: {
            HStack(spacing: 12) {
                OtoIcon(name: isOn ? "circle-check" : "circle", size: 18)
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
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius)
                    .strokeBorder(isOn ? Color.otoTeal.opacity(0.4) : OtoUI.strokeColor.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
