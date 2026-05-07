import SwiftUI

struct RulesView: View {
    @EnvironmentObject var state: AppState
    @State private var filter: Filter = .all
    @State private var editingRule: Rule? = nil
    @State private var showingAdd = false

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
            ScrollView {
                VStack(spacing: 12) {
                    if state.store.rules.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredRules) { rule in
                            RuleRow(rule: rule, onEdit: { editingRule = rule })
                        }
                    }
                }
                .padding(.bottom, 24)
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
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules").font(.largeTitle).bold()
                Text("Oto automatically switches your input based on these rules.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingAdd = true
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No rules yet").font(.headline)
            Text("Add a rule and Oto will switch your input automatically when devices connect, disconnect, or your Mac wakes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                showingAdd = true
            } label: {
                Label("Create your first rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

    var body: some View {
        HStack(spacing: 14) {
            triggerIconTile

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.trigger.displayText)
                    .font(.callout.weight(.medium))
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right").font(.caption2)
                    if !rule.action.prefixText.isEmpty {
                        Text(rule.action.prefixText)
                            .foregroundStyle(.secondary)
                    }
                    Text(rule.action.displayText)
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
                Divider()
                Button("Delete", role: .destructive) {
                    state.store.delete(rule)
                }
            } label: {
                Image(systemName: "ellipsis")
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
        return Image(systemName: info.icon)
            .font(.system(size: 18))
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
            return ("wave.3.right", .otoTeal)
        case .systemWakes:
            return ("power", .otoNavy)
        }
    }

    private func tileFor(uid: String, name: String, fallbackColor: Color) -> (icon: String, color: Color) {
        if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
            return (device.kind.systemImage, device.displayTint)
        }
        let lower = name.lowercased()
        if lower.contains("airpods") { return ("airpods.pro", .otoNavy) }
        if lower.contains("wh-") || lower.contains("headphone") { return ("headphones", .otoTeal) }
        if lower.contains("yeti") { return ("mic.fill", .otoAlert) }
        return ("mic.fill", fallbackColor)
    }

    private var actionColor: Color {
        switch rule.action {
        case .setInput(let uid, _):
            if let device = state.monitor.allDevices.first(where: { $0.uid == uid }) {
                return device.displayTint
            }
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
    @State private var actionDeviceUID: String = ""
    @State private var actionDeviceName: String = ""

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
        case setInput, keepCurrent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .setInput: return "Set input to"
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
                if actionKind == .setInput {
                    Picker("Input", selection: $actionDeviceUID) {
                        Text("Select input").tag("")
                        ForEach(state.inputDevices, id: \.uid) { d in
                            Text(d.name).tag(d.uid)
                        }
                    }
                    .onChange(of: actionDeviceUID) { _, newValue in
                        actionDeviceName = state.inputDevices.first(where: { $0.uid == newValue })?.name ?? actionDeviceName
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
        .frame(width: 480)
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        guard let r = existing else { return }
        switch r.trigger {
        case .deviceConnects(let uid, let name):
            triggerKind = .deviceConnects
            triggerDeviceUID = uid
            triggerDeviceName = name
        case .deviceDisconnects(let uid, let name):
            triggerKind = .deviceDisconnects
            triggerDeviceUID = uid
            triggerDeviceName = name
        case .anyBluetoothConnects:
            triggerKind = .anyBluetooth
        case .systemWakes:
            triggerKind = .systemWakes
        }
        switch r.action {
        case .setInput(let uid, let name):
            actionKind = .setInput
            actionDeviceUID = uid
            actionDeviceName = name
        case .keepCurrent:
            actionKind = .keepCurrent
        }
    }

    private var isValid: Bool {
        switch triggerKind {
        case .deviceConnects, .deviceDisconnects:
            if triggerDeviceUID.isEmpty { return false }
        case .anyBluetooth, .systemWakes:
            break
        }
        if actionKind == .setInput, actionDeviceUID.isEmpty { return false }
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
            let name = state.inputDevices.first(where: { $0.uid == actionDeviceUID })?.name ?? actionDeviceName
            action = .setInput(deviceUID: actionDeviceUID, deviceName: name)
        case .keepCurrent:
            action = .keepCurrent
        }
        if let r = existing {
            return Rule(id: r.id, trigger: trigger, action: action, enabled: r.enabled)
        }
        return Rule(trigger: trigger, action: action)
    }
}
