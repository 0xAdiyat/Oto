import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    let openMain: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.vertical, 6)
            currentInputSection
            Divider().padding(.vertical, 6)
            connectedInputsSection
            Divider().padding(.vertical, 6)
            footer
        }
        .padding(12)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("LogoMark")
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
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Oto")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
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
            Image(systemName: device.kind.systemImage)
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
