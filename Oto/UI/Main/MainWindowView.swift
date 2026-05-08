import SwiftUI

/// Spotlight-style root view: borderless transparent window contents.
/// Header pill on top, filter bar, then the rules panel — staggered entrance
/// animation matches media-downloader's ContentView reveal.
struct MainWindowView: View {
    @Environment(AppState.self) private var state

    @State private var headerAppeared = false
    @State private var filtersAppeared = false
    @State private var panelAppeared = false

    @State private var revealTask: Task<Void, Never>?
    @State private var filter: RuleFilter = .all
    @State private var sheet: ActiveSheet?
    @State private var editingRule: Rule? = nil

    enum ActiveSheet: Identifiable {
        case addRule, templates, profiles, devices, settings, about
        var id: String {
            switch self {
            case .addRule: return "add"
            case .templates: return "templates"
            case .profiles: return "profiles"
            case .devices: return "devices"
            case .settings: return "settings"
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
                    onShowSettings: { sheet = .settings },
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { runRevealAnimation() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            runRevealAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            headerAppeared = false
            filtersAppeared = false
            panelAppeared = false
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .addRule:
                RuleEditorSheet(existing: nil).environment(state)
            case .templates:
                TemplatesSheet().environment(state)
            case .profiles:
                ProfilesSheet().environment(state)
            case .devices:
                DevicesSheet().environment(state)
            case .settings:
                SettingsSheet()
            case .about:
                AboutSheet()
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(existing: rule).environment(state)
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

// MARK: - Filter

enum RuleFilter: String, CaseIterable, Identifiable {
    case all, active, inactive
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct FilterTabsBar: View {
    @Environment(AppState.self) private var state
    @Binding var filter: RuleFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RuleFilter.allCases) { f in
                let isOn = filter == f
                Button {
                    filter = f
                } label: {
                    HStack(spacing: 6) {
                        Text(f.label)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(count(for: f))")
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(OtoUI.rowIdle, in: Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isOn ? Color.otoTeal.opacity(0.18) : Color.clear, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(isOn ? Color.otoTeal.opacity(0.45) : OtoUI.dividerColor, lineWidth: 1)
                    }
                    .foregroundStyle(isOn ? Color.otoTeal : OtoUI.secondaryFG)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if filter != .all {
                Text("Drag to reorder available in All")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
            }
        }
        .frame(width: OtoUI.pillWidth)
        .padding(.horizontal, 4)
    }

    private func count(for f: RuleFilter) -> Int {
        switch f {
        case .all: return state.store.rules.count
        case .active: return state.store.rules.filter(\.enabled).count
        case .inactive: return state.store.rules.filter { !$0.enabled }.count
        }
    }
}
