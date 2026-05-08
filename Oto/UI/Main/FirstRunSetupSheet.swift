import SwiftUI

struct FirstRunSetupSheet: View {
    @Environment(AppState.self) private var state

    @State private var step: SetupStep = .welcome
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var preferredInputUID = ""
    @State private var preferredOutputUID = ""
    @State private var selectedTemplateIDs: Set<UUID> = []
    @State private var templates: [RuleTemplates.Suggestion] = []
    @State private var hotkey: HotkeyShortcut?

    private enum SetupStep: Int, CaseIterable {
        case welcome, devices, templates, hotkey

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .devices: return "Devices"
            case .templates: return "Automations"
            case .hotkey: return "Hotkey"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            progress

            Group {
                switch step {
                case .welcome: welcomeStep
                case .devices: devicesStep
                case .templates: templatesStep
                case .hotkey: hotkeyStep
                }
            }
            .frame(height: 290, alignment: .top)

            footer
        }
        .padding(26)
        .frame(width: 620)
        .materialPanel()
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            hotkey = GlobalHotkeyManager.shared.shortcut
            templates = RuleTemplates.suggestions(for: state.monitor.allDevices)
            preferredInputUID = state.monitor.defaultInputDevice?.uid ?? state.inputDevices.first?.uid ?? ""
            preferredOutputUID = state.monitor.defaultOutputDevice?.uid ?? state.monitor.allDevices.first(where: \.hasOutput)?.uid ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Set up Oto")
                .font(.system(size: OtoUI.titleSize, weight: .semibold))
            Text("Choose the defaults Oto should protect, then start with a few useful automations.")
                .font(.system(size: OtoUI.metaSize))
                .foregroundStyle(OtoUI.mutedFG)
        }
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(SetupStep.allCases, id: \.self) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.rawValue <= step.rawValue ? Color.otoTeal : OtoUI.rowHover)
                        .frame(width: 7, height: 7)
                    Text(item.title)
                        .font(.system(size: OtoUI.captionSize, weight: item == step ? .semibold : .regular))
                        .foregroundStyle(item == step ? OtoUI.secondaryFG : OtoUI.mutedFG)
                }
                if item != SetupStep.allCases.last {
                    Rectangle()
                        .fill(OtoUI.dividerColor)
                        .frame(height: 1)
                }
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupCard(icon: "menubar.rectangle", title: "Menu bar first", subtitle: "Oto stays out of the Dock and opens from the menu bar or hotkey.")
            setupCard(icon: "wand.and.stars", title: "Rules do the switching", subtitle: "Automations run when devices connect, apps launch, or your Mac wakes.")
            Toggle("Launch Oto when I log in", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
                .padding(14)
                .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
        }
    }

    private var devicesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick preferred defaults. Oto can restore these on wake.")
                .font(.system(size: OtoUI.metaSize))
                .foregroundStyle(OtoUI.mutedFG)

            FormRow(label: "Input") {
                Picker("", selection: $preferredInputUID) {
                    Text("No preferred input").tag("")
                    ForEach(state.inputDevices, id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .labelsHidden()
            }

            FormRow(label: "Output", isLast: true) {
                Picker("", selection: $preferredOutputUID) {
                    Text("No preferred output").tag("")
                    ForEach(state.monitor.allDevices.filter(\.hasOutput), id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .labelsHidden()
            }
        }
        .padding(14)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.cardRadius, style: .continuous))
    }

    private var templatesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starter automations")
                .font(.system(size: 15, weight: .semibold))
            if templates.isEmpty {
                Text("Connect an external audio device later and Oto can suggest templates then.")
                    .font(.system(size: OtoUI.metaSize))
                    .foregroundStyle(OtoUI.mutedFG)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(templates) { template in
                            templateButton(template)
                        }
                    }
                }
            }
        }
    }

    private var hotkeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupCard(icon: "command", title: "Open Oto from anywhere", subtitle: "A global hotkey can summon the panel even while another app is fullscreen.")
            HStack {
                Text("Open Oto")
                    .font(.system(size: OtoUI.metaSize, weight: .medium))
                Spacer()
                HotkeyRecorder(shortcut: $hotkey) { new in
                    GlobalHotkeyManager.shared.update(new)
                    hotkey = GlobalHotkeyManager.shared.shortcut
                }
            }
            .padding(14)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip") { state.completeFirstRunSetup() }
                .buttonStyle(.plain)
                .foregroundStyle(OtoUI.mutedFG)

            Spacer()

            if step != .welcome {
                Button("Back") { move(-1) }
                    .buttonStyle(.plain)
                    .foregroundStyle(OtoUI.secondaryFG)
            }

            Button(step == .hotkey ? "Finish" : "Continue") {
                if step == .hotkey {
                    finish()
                } else {
                    move(1)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.otoTeal)
        }
    }

    private func setupCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            OtoIcon(name: icon, size: 17)
                .frame(width: 36, height: 36)
                .background(Color.otoTeal.opacity(0.16), in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius, style: .continuous))
                .foregroundStyle(Color.otoTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: OtoUI.metaSize, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: OtoUI.captionSize))
                    .foregroundStyle(OtoUI.mutedFG)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
    }

    private func templateButton(_ template: RuleTemplates.Suggestion) -> some View {
        let isSelected = selectedTemplateIDs.contains(template.id)
        return Button {
            if isSelected {
                selectedTemplateIDs.remove(template.id)
            } else {
                selectedTemplateIDs.insert(template.id)
            }
        } label: {
            HStack(spacing: 10) {
                OtoIcon(name: isSelected ? "checkmark.circle.fill" : "circle", size: 17)
                    .foregroundStyle(isSelected ? Color.otoTeal : OtoUI.mutedFG)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.system(size: OtoUI.metaSize, weight: .medium))
                    Text(template.subtitle)
                        .font(.system(size: OtoUI.captionSize))
                        .foregroundStyle(OtoUI.mutedFG)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.otoTeal.opacity(0.45) : OtoUI.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func move(_ delta: Int) {
        let next = max(0, min(SetupStep.allCases.count - 1, step.rawValue + delta))
        step = SetupStep(rawValue: next) ?? step
    }

    private func finish() {
        addPreferredWakeRule()
        for template in templates where selectedTemplateIDs.contains(template.id) {
            for rule in template.rules {
                state.store.add(rule)
            }
        }
        state.completeFirstRunSetup()
    }

    private func addPreferredWakeRule() {
        let input = state.inputDevices.first(where: { $0.uid == preferredInputUID })
        let output = state.monitor.allDevices.first(where: { $0.uid == preferredOutputUID && $0.hasOutput })

        switch (input, output) {
        case (.some(let input), .some(let output)):
            state.store.add(Rule(
                trigger: .systemWakes,
                action: .setBoth(inputUID: input.uid, inputName: input.name, outputUID: output.uid, outputName: output.name)
            ))
        case (.some(let input), .none):
            state.store.add(Rule(trigger: .systemWakes, action: .setInput(deviceUID: input.uid, deviceName: input.name)))
        case (.none, .some(let output)):
            state.store.add(Rule(trigger: .systemWakes, action: .setOutput(deviceUID: output.uid, deviceName: output.name)))
        case (.none, .none):
            break
        }
    }
}
