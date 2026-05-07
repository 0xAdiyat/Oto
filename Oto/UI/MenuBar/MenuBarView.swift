import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var levelMonitor = InputLevelMonitor()
    let openMain: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if !state.store.profiles.isEmpty {
                Divider().padding(.vertical, 6)
                profileSection
            }
            Divider().padding(.vertical, 6)
            currentInputSection
            Divider().padding(.vertical, 6)
            connectedInputsSection
            Divider().padding(.vertical, 6)
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { levelMonitor.start() }
        .onDisappear { levelMonitor.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
            Text("Oto").font(.headline)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color.otoTeal).frame(width: 7, height: 7)
                Text("Active").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: openMain) {
                OtoIcon(name: "settings", size: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var profileSection: some View {
        HStack(spacing: 8) {
            Text("Profile").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button {
                    state.store.activeProfileID = nil
                } label: {
                    Text("All rules active")
                }
                Divider()
                ForEach(state.store.profiles) { p in
                    Button {
                        state.store.activeProfileID = p.id
                    } label: {
                        Text(p.name)
                    }
                }
            } label: {
                let active = state.store.profiles.first(where: { $0.id == state.store.activeProfileID })
                HStack(spacing: 4) {
                    Text(active?.name ?? "All").font(.caption.bold())
                    OtoIcon(name: "chevron-down", size: 10)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var currentInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Input")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let current = state.monitor.defaultInputDevice {
                DeviceRow(device: current, trailing: {
                    AnyView(
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    )
                })
                LevelBar(level: levelMonitor.level)
                    .frame(height: 4)
                    .padding(.horizontal, 4)
            } else {
                Text("No input device").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var connectedInputsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connected Inputs")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(otherInputs) { device in
                DeviceRow(device: device, trailing: {
                    AnyView(
                        Button("Switch") { state.switchTo(device) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    )
                })
            }
        }
    }

    private var otherInputs: [AudioDevice] {
        let currentUID = state.monitor.defaultInputDevice?.uid
        return state.inputDevices.filter { $0.uid != currentUID }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Button(action: openMain) {
                HStack {
                    OtoIcon(name: "square-arrow-out-up-right", size: 14)
                    Text("Open Oto")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    OtoIcon(name: "power", size: 14)
                    Text("Quit Oto")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let trailing: () -> AnyView

    var body: some View {
        HStack(spacing: 10) {
            OtoIcon(name: device.kind.systemImage, size: 16)
                .frame(width: 32, height: 32)
                .background(device.displayTint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(device.displayTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.callout)
                Text(device.kind.label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }
}

private struct LevelBar: View {
    let level: Float
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.otoTeal, .otoYellow, .otoAlert], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, geo.size.width * CGFloat(level)))
            }
        }
    }
}
