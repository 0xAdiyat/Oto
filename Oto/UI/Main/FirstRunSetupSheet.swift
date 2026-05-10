import SwiftUI

struct FirstRunSetupSheet: View {
    @Environment(AppState.self) private var state

    @State private var step: SetupStep = .welcome
    @State private var visitedSteps: Set<SetupStep> = [.welcome]
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var preferredInputUID = ""
    @State private var preferredOutputUID = ""
    @State private var selectedTemplateIDs: Set<UUID> = []
    @State private var templates: [RuleTemplates.Suggestion] = []
    @State private var hotkey: HotkeyShortcut?

    private enum SetupStep: Int, CaseIterable, Hashable {
        case welcome, devices, templates, hotkey

        var title: String {
            switch self {
            case .welcome:   return "Welcome"
            case .devices:   return "Devices"
            case .templates: return "Automations"
            case .hotkey:    return "Hotkey"
            }
        }

        var headline: String {
            switch self {
            case .welcome:   return "Welcome to Oto"
            case .devices:   return "Pick your defaults"
            case .templates: return "Starter automations"
            case .hotkey:    return "Set a global hotkey"
            }
        }

        var description: String {
            switch self {
            case .welcome:   return "Oto switches your Mac's audio automatically — when devices connect, apps launch, or your Mac wakes."
            case .devices:   return "Oto can restore these whenever your Mac wakes. You can change them anytime."
            case .templates: return "Pick a few ready-made rules that match your devices. You can edit or delete them later."
            case .hotkey:    return "Summon Oto from anywhere — even while another app is fullscreen."
            }
        }

        var icon: String {
            switch self {
            case .welcome:   return "sparkles"
            case .devices:   return "waveform"
            case .templates: return "wand.and.stars"
            case .hotkey:    return "command"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 18)

            Divider()
                .background(OtoUI.dividerColor)

            stepHeader
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 18)

            stepContent
                .padding(.horizontal, 28)
                .frame(minHeight: 240, alignment: .top)

            Spacer(minLength: 18)

            Divider()
                .background(OtoUI.dividerColor)

            footer
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
        }
        .frame(width: 620, height: 560)
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

    // MARK: - Progress indicator

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(Array(SetupStep.allCases.enumerated()), id: \.element) { index, item in
                progressNode(item, index: index)
                if item != SetupStep.allCases.last {
                    progressConnector(after: item)
                }
            }
        }
    }

    private func progressNode(_ item: SetupStep, index: Int) -> some View {
        let isCurrent = item == step
        let isCompleted = item.rawValue < step.rawValue
        let canJump = visitedSteps.contains(item)

        return Button {
            guard canJump else { return }
            withAnimation(.easeOut(duration: 0.20)) { step = item }
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isCurrent || isCompleted ? Color.otoTeal : OtoUI.rowIdle)
                        .frame(width: 18, height: 18)
                    if isCompleted {
                        OtoIcon(name: "checkmark", size: 9, weight: .bold)
                            .foregroundStyle(Color.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isCurrent ? Color.white : OtoUI.mutedFG)
                    }
                }
                Text(item.title)
                    .font(.system(size: 11.5, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? OtoUI.secondaryFG : OtoUI.mutedFG)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canJump)
        .help(canJump ? "Jump to \(item.title)" : "Available after you continue")
    }

    private func progressConnector(after item: SetupStep) -> some View {
        let reached = item.rawValue < step.rawValue
        return Rectangle()
            .fill(reached ? Color.otoTeal.opacity(0.55) : OtoUI.dividerColor)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Step header (adapts per step)

    private var stepHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.otoTeal.opacity(0.18))
                OtoIcon(name: step.icon, size: 19, weight: .medium)
                    .foregroundStyle(Color.otoTeal)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.headline)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OtoUI.primaryFG)
                Text(step.description)
                    .font(.system(size: 12.5))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Step content with crossfade transition

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .welcome:   welcomeStep
            case .devices:   devicesStep
            case .templates: templatesStep
            case .hotkey:    hotkeyStep
            }
        }
        .id(step)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(x: 12, y: 0)),
                removal: .opacity.combined(with: .offset(x: -12, y: 0))
            )
        )
        .animation(.easeOut(duration: 0.22), value: step)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            highlightCard(icon: "menubar.rectangle", title: "Lives in the menu bar", subtitle: "No Dock icon — opens from the menu bar or your hotkey.")
            highlightCard(icon: "gearshape.2", title: "Rules do the switching", subtitle: "Automations run on device connect, app launch, or wake.")

            Toggle(isOn: $launchAtLogin) {
                HStack(spacing: 10) {
                    OtoIcon(name: "power", size: 14)
                        .foregroundStyle(Color.otoTeal)
                    Text("Launch Oto when I log in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OtoUI.secondaryFG)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: launchAtLogin) { _, newValue in
                LaunchAtLogin.setEnabled(newValue)
                launchAtLogin = LaunchAtLogin.isEnabled
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                    .strokeBorder(OtoUI.dividerColor, lineWidth: 1)
            }
        }
    }

    private var devicesStep: some View {
        VStack(spacing: 10) {
            devicePickerRow(
                label: "Default input",
                icon: "mic",
                selection: $preferredInputUID,
                options: state.inputDevices,
                placeholder: "Don't restore"
            )
            devicePickerRow(
                label: "Default output",
                icon: "speaker.wave.2",
                selection: $preferredOutputUID,
                options: state.monitor.allDevices.filter(\.hasOutput),
                placeholder: "Don't restore"
            )

            Text("Tip: leave either as \"Don't restore\" if you'd rather keep macOS's choice.")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    private func devicePickerRow(
        label: String,
        icon: String,
        selection: Binding<String>,
        options: [AudioDevice],
        placeholder: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.otoTeal.opacity(0.14))
                OtoIcon(name: icon, size: 13)
                    .foregroundStyle(Color.otoTeal)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(OtoUI.secondaryFG)

            Spacer()

            Picker("", selection: selection) {
                Text(placeholder).tag("")
                ForEach(options, id: \.uid) { device in
                    Text(device.name).tag(device.uid)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                .strokeBorder(OtoUI.dividerColor, lineWidth: 1)
        }
    }

    private var templatesStep: some View {
        Group {
            if templates.isEmpty {
                emptyTemplates
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(templates) { template in
                            templateButton(template)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private var emptyTemplates: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.otoYellow.opacity(0.16))
                OtoIcon(name: "sparkles", size: 18)
                    .foregroundStyle(Color.otoYellow)
            }
            .frame(width: 44, height: 44)

            Text("No suggestions just yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OtoUI.secondaryFG)
            Text("Connect an external audio device later and Oto will suggest rule templates that match it.")
                .font(.system(size: 12))
                .foregroundStyle(OtoUI.mutedFG)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var hotkeyStep: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.otoTeal.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.otoTeal.opacity(0.32), lineWidth: 1)
                    }
                VStack(spacing: 8) {
                    OtoIcon(name: "command.circle.fill", size: 26)
                        .foregroundStyle(Color.otoTeal)
                    Text(hotkey?.displayString ?? "Not set")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(OtoUI.primaryFG)
                    Text("Press a combination to record a new shortcut.")
                        .font(.system(size: 11))
                        .foregroundStyle(OtoUI.mutedFG)
                }
                .padding(20)
            }
            .frame(height: 130)

            HStack(spacing: 12) {
                Text("Shortcut")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(OtoUI.secondaryFG)
                Spacer()
                HotkeyRecorder(shortcut: $hotkey) { new in
                    GlobalHotkeyManager.shared.update(new)
                    hotkey = GlobalHotkeyManager.shared.shortcut
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                    .strokeBorder(OtoUI.dividerColor, lineWidth: 1)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Skip setup") { state.completeFirstRunSetup() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.mutedFG)

            Spacer()

            if step != .welcome {
                Button("Back") {
                    withAnimation(.easeOut(duration: 0.20)) { move(-1) }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Button(step == .hotkey ? "Finish setup" : "Continue") {
                withAnimation(.easeOut(duration: 0.20)) {
                    if step == .hotkey {
                        finish()
                    } else {
                        move(1)
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.otoTeal)
        }
    }

    // MARK: - Step content helpers

    private func highlightCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.otoTeal.opacity(0.16))
                OtoIcon(name: icon, size: 16)
                    .foregroundStyle(Color.otoTeal)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OtoUI.secondaryFG)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                .strokeBorder(OtoUI.dividerColor, lineWidth: 1)
        }
    }

    private func templateButton(_ template: RuleTemplates.Suggestion) -> some View {
        let isSelected = selectedTemplateIDs.contains(template.id)
        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                if isSelected {
                    selectedTemplateIDs.remove(template.id)
                } else {
                    selectedTemplateIDs.insert(template.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.otoTeal : Color.clear)
                        .overlay {
                            Circle().strokeBorder(isSelected ? Color.clear : OtoUI.mutedFG.opacity(0.5), lineWidth: 1.5)
                        }
                    if isSelected {
                        OtoIcon(name: "checkmark", size: 9, weight: .bold)
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OtoUI.secondaryFG)
                    Text(template.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(OtoUI.mutedFG)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)

                if template.rules.count > 1 {
                    Text("\(template.rules.count) rules")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(OtoUI.rowIdle, in: Capsule())
                        .foregroundStyle(OtoUI.mutedFG)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                isSelected ? Color.otoTeal.opacity(0.12) : OtoUI.rowIdle,
                in: RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OtoUI.chipRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.otoTeal.opacity(0.55) : OtoUI.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func move(_ delta: Int) {
        let next = max(0, min(SetupStep.allCases.count - 1, step.rawValue + delta))
        if let nextStep = SetupStep(rawValue: next) {
            step = nextStep
            visitedSteps.insert(nextStep)
        }
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

#if DEBUG
#Preview("First-run setup") {
    FirstRunSetupSheet()
        .environment(AppState.previewPopulated)
        .padding(40)
        .background(Color.black)
}
#endif
