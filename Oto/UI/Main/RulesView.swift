import SwiftUI

struct RulesView: View {
    @EnvironmentObject var state: AppState
    @State private var filter: Filter = .all
    @State private var editingRule: Rule? = nil
    @State private var showingAdd = false
    @State private var showingTemplates = false
    @State private var showingProfiles = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, active, inactive
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var filteredRules: [Rule] {
        switch filter {
        case .all: return state.store.rules
        case .active: return state.store.rules.filter(\.enabled)
        case .inactive: return state.store.rules.filter { !$0.enabled }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !state.store.rules.isEmpty {
                filterTabs
            }
            if state.store.rules.isEmpty {
                ScrollView { emptyState.padding(.bottom, 24) }
            } else {
                rulesList
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAdd) {
            RuleEditorSheet(existing: nil)
                .environmentObject(state)
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(existing: rule)
                .environmentObject(state)
        }
        .sheet(isPresented: $showingTemplates) {
            TemplatesSheet()
                .environmentObject(state)
        }
    }

    private var rulesList: some View {
        // List with .onMove for drag-reorder. We always render against the
        // full ordered list and let the user drag any row, but visually filter
        // by greying out non-matching rows? Simpler: only allow reordering in
        // "All" view; in filtered views, reordering is hidden.
        List {
            ForEach(filter == .all ? state.store.rules : filteredRules) { rule in
                RuleRow(rule: rule, onEdit: { editingRule = rule })
                    .contextMenu {
                        Button("Edit") { editingRule = rule }
                        Button("Duplicate") { state.store.duplicate(rule) }
                        Button(rule.enabled ? "Disable" : "Enable") { state.store.toggle(rule) }
                        Divider()
                        Button("Delete", role: .destructive) { state.store.delete(rule) }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .onMove { src, dst in
                guard filter == .all else { return }
                state.store.move(fromOffsets: src, toOffset: dst)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules").font(.largeTitle).bold()
                Text("Oto automatically switches your input based on these rules.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            profilePicker
            Menu {
                Button("Add custom rule…") { showingAdd = true }
                Button("From template…") { showingTemplates = true }
            } label: {
                Label { Text("Add Rule") } icon: { OtoIcon(name: "plus", size: 14) }
            } primaryAction: {
                showingAdd = true
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fixedSize()
        }
        .sheet(isPresented: $showingProfiles) {
            ProfilesSheet().environmentObject(state)
        }
    }

    private var profilePicker: some View {
        Menu {
            Button {
                state.store.activeProfileID = nil
            } label: {
                HStack {
                    Text("All rules active")
                    if state.store.activeProfileID == nil {
                        OtoIcon(name: "check", size: 12)
                    }
                }
            }
            if !state.store.profiles.isEmpty {
                Divider()
                ForEach(state.store.profiles) { p in
                    Button {
                        state.store.activeProfileID = p.id
                    } label: {
                        Label { Text(p.name) } icon: { OtoIcon(name: p.icon, size: 14) }
                        if state.store.activeProfileID == p.id {
                            OtoIcon(name: "check", size: 12)
                        }
                    }
                }
            }
            Divider()
            Button("Manage profiles…") { showingProfiles = true }
        } label: {
            HStack(spacing: 6) {
                let active = state.store.profiles.first(where: { $0.id == state.store.activeProfileID })
                OtoIcon(name: active?.icon ?? "grid-2x2", size: 14)
                Text(active?.name ?? "All profiles")
                OtoIcon(name: "chevron-down", size: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(Filter.allCases) { f in
                let count: Int = {
                    switch f {
                    case .all: return state.store.rules.count
                    case .active: return state.store.rules.filter(\.enabled).count
                    case .inactive: return state.store.rules.filter { !$0.enabled }.count
                    }
                }()
                Button {
                    filter = f
                } label: {
                    HStack(spacing: 6) {
                        Text(f.label)
                        Text("\(count)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.18), in: Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(filter == f ? Color.accentColor.opacity(0.15) : Color.clear, in: Capsule())
                    .foregroundStyle(filter == f ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
            }
            if filter != .all {
                Text("Drag to reorder available in All")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            OtoIcon(name: "list-checks", size: 36)
                .foregroundStyle(.secondary)
            Text("No rules yet").font(.headline)
            Text("Add a rule and Oto will switch your input automatically when devices connect, disconnect, or your Mac wakes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 8) {
                Button {
                    showingAdd = true
                } label: {
                    Label { Text("Create custom rule") } icon: { OtoIcon(name: "plus", size: 14) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button {
                    showingTemplates = true
                } label: {
                    Label { Text("From template") } icon: { OtoIcon(name: "wand-sparkles", size: 14) }
                }
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct RuleRow: View {
    @EnvironmentObject var state: AppState
    let rule: Rule
    let onEdit: () -> Void

    /// EC6: re-resolve display name from current device list when available.
    private func resolvedName(uid: String, fallback: String) -> String {
        state.monitor.allDevices.first(where: { $0.uid == uid })?.name ?? fallback
    }

    private var triggerDisplayText: String {
        switch rule.trigger {
        case .deviceConnects(let uid, let name):
            return "When \(resolvedName(uid: uid, fallback: name)) connects"
        case .deviceDisconnects(let uid, let name):
            return "When \(resolvedName(uid: uid, fallback: name)) disconnects"
        case .anyBluetoothConnects: return rule.trigger.displayText
        case .systemWakes: return rule.trigger.displayText
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
            triggerIconTile

            VStack(alignment: .leading, spacing: 4) {
                Text(triggerDisplayText)
                    .font(.callout.weight(.medium))
                HStack(spacing: 4) {
                    OtoIcon(name: "arrow-right", size: 10)
                    if !rule.action.prefixText.isEmpty {
                        Text(rule.action.prefixText)
                            .foregroundStyle(.secondary)
                    }
                    Text(actionDisplayText)
                        .foregroundStyle(actionColor)
                        .fontWeight(.medium)
                    if case .keepCurrent = rule.action {
                        Text("(do nothing)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in state.store.toggle(rule) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            Menu {
                Button("Edit", action: onEdit)
                Button("Duplicate") { state.store.duplicate(rule) }
                Button(rule.enabled ? "Disable" : "Enable") { state.store.toggle(rule) }
                Divider()
                Button("Delete", role: .destructive) {
                    state.store.delete(rule)
                }
            } label: {
                OtoIcon(name: "ellipsis", size: 16)
                    .padding(8)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .opacity(rule.enabled ? 1.0 : 0.55)
    }

    private var triggerIconTile: some View {
        let info = triggerIconInfo
        return OtoIcon(name: info.icon, size: 20)
            .frame(width: 40, height: 40)
            .background(info.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(info.color)
    }

    private var triggerIconInfo: (icon: String, color: Color) {
        switch rule.trigger {
        case .deviceConnects(let uid, let name):
            return tileFor(uid: uid, name: name, fallbackColor: .otoTeal)
        case .deviceDisconnects(let uid, let name):
            let info = tileFor(uid: uid, name: name, fallbackColor: .otoYellow)
            return (info.icon, .otoYellow)
        case .anyBluetoothConnects:
            return ("bluetooth", .otoTeal)
        case .systemWakes:
            return ("power", .otoNavy)
        }
    }

    private func tileFor(uid: String, name: String, fallbackColor: Color) -> (icon: String, color: Color) {
        if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
            return (device.kind.systemImage, device.displayTint)
        }
        let lower = name.lowercased()
        if lower.contains("airpods") { return ("ear", .otoNavy) }
        if lower.contains("wh-") || lower.contains("headphone") { return ("headphones", .otoTeal) }
        if lower.contains("yeti") { return ("mic", .otoAlert) }
        return ("mic", fallbackColor)
    }

    private var actionColor: Color {
        switch rule.action {
        case .setInput(let uid, _), .setOutput(let uid, _):
            if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
                return device.displayTint
            }
            return .accentColor
        case .setBoth, .setInputVolume, .toggleInputMute:
            return .accentColor
        case .keepCurrent:
            return .accentColor
        }
    }
}

private struct RuleEditorSheet: View {
    @EnvironmentObject var state: AppState
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
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Rule" : "Edit Rule").font(.title2).bold()

            Form {
                Picker("Trigger", selection: $triggerKind) {
                    ForEach(TriggerKind.allCases) { k in Text(k.label).tag(k) }
                }
                if triggerKind == .deviceConnects || triggerKind == .deviceDisconnects {
                    Picker("Device", selection: $triggerDeviceUID) {
                        Text("Select device").tag("")
                        ForEach(state.monitor.allDevices, id: \.uid) { d in
                            Text(d.name).tag(d.uid)
                        }
                    }
                    .onChange(of: triggerDeviceUID) { _, newValue in
                        triggerDeviceName = state.monitor.allDevices.first(where: { $0.uid == newValue })?.name ?? triggerDeviceName
                    }
                }

                Picker("Action", selection: $actionKind) {
                    ForEach(ActionKind.allCases) { k in Text(k.label).tag(k) }
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
                    HStack {
                        Slider(value: $volume, in: 0...1)
                        Text("\(Int(volume * 100))%").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                case .toggleInputMute, .keepCurrent:
                    EmptyView()
                }

                Picker("Profile", selection: profileBinding) {
                    Text("Always active").tag(Optional<UUID>.none)
                    ForEach(state.store.profiles) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
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
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear(perform: hydrate)
    }

    @ViewBuilder
    private var inputPicker: some View {
        Picker("Input", selection: $inputDeviceUID) {
            Text("Select input").tag("")
            ForEach(state.inputDevices, id: \.uid) { d in
                Text(d.name).tag(d.uid)
            }
        }
        .onChange(of: inputDeviceUID) { _, newValue in
            inputDeviceName = state.inputDevices.first(where: { $0.uid == newValue })?.name ?? inputDeviceName
        }
    }

    @ViewBuilder
    private var outputPicker: some View {
        Picker("Output", selection: $outputDeviceUID) {
            Text("Select output").tag("")
            ForEach(state.monitor.allDevices.filter(\.hasOutput), id: \.uid) { d in
                Text(d.name).tag(d.uid)
            }
        }
        .onChange(of: outputDeviceUID) { _, newValue in
            outputDeviceName = state.monitor.allDevices.first(where: { $0.uid == newValue })?.name ?? outputDeviceName
        }
    }

    private var profileBinding: Binding<UUID?> {
        Binding(get: { profileID }, set: { profileID = $0 })
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

// MARK: - Templates

private struct TemplatesSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []

    var templates: [RuleTemplates.Suggestion] {
        RuleTemplates.suggestions(for: state.monitor.allDevices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rule Templates").font(.title2).bold()
            Text("Suggestions based on your connected devices. Pick the ones you want.")
                .foregroundStyle(.secondary)

            if templates.isEmpty {
                Text("No suggestions available. Connect some audio devices first.")
                    .foregroundStyle(.secondary)
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
                Button("Add Selected") {
                    for t in templates where selected.contains(t.id) {
                        for r in t.rules { state.store.add(r) }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func templateRow(_ t: RuleTemplates.Suggestion) -> some View {
        let isOn = selected.contains(t.id)
        return Button {
            if isOn { selected.remove(t.id) } else { selected.insert(t.id) }
        } label: {
            HStack(spacing: 12) {
                OtoIcon(name: isOn ? "circle-check" : "circle", size: 18)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.callout.weight(.medium))
                    Text(t.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
