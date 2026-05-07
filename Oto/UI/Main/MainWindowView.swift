import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview, rules, devices, settings, about
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .rules: return "Rules"
        case .devices: return "Devices"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "house"
        case .rules: return "list.bullet.rectangle"
        case .devices: return "ipad.landscape"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: SidebarSection = .rules

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("")
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("LogoFull")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            List(selection: $selection) {
                ForEach(SidebarSection.allCases) { section in
                    Label {
                        HStack {
                            Text(section.label)
                            Spacer()
                            if section == .rules {
                                Text("\(state.store.rules.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: section.systemImage)
                    }
                    .tag(section)
                }
            }
            .listStyle(.sidebar)

            Spacer()
            statusCard
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Color.otoTeal).frame(width: 7, height: 7)
                    Text("Active").font(.caption.bold())
                }
                Text("v1.0.0").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(12)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview: OverviewView()
        case .rules: RulesView()
        case .devices: DevicesView()
        case .settings: SettingsView()
        case .about: AboutView()
        }
    }
}
