import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Editor for the full-screen break overlay's appearance (the "Customize break
/// screen" row in Screen Breaks settings). Presented as a sheet from the
/// standard Settings window. Edits a `BreakScreenStyle` binding live, with a
/// scaled preview of the break screen.
struct CustomizeBreakScreenView: View {
    @Binding var style: BreakScreenStyle
    var onClose: () -> Void

    @State private var color: Color

    init(style: Binding<BreakScreenStyle>, onClose: @escaping () -> Void) {
        self._style = style
        self.onClose = onClose
        self._color = State(initialValue: Color(hexString: style.wrappedValue.colorHex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Customize break screen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OtoUI.primaryFG)
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }

            preview

            VStack(spacing: 14) {
                SettingsFieldRow(label: "Background") {
                    Picker("", selection: $style.background) {
                        ForEach(BreakScreenStyle.Background.allCases, id: \.self) {
                            Text($0.label).tag($0)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if style.background != .image {
                    SettingsFieldRow(label: "Color") {
                        ColorPicker("", selection: $color, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: color) { _, new in style.colorHex = new.hexString }
                    }
                } else {
                    SettingsFieldRow(label: "Image") {
                        Button(style.imageBookmark == nil ? "Choose image…" : "Replace image…") {
                            chooseImage()
                        }
                        .controlSize(.small)
                    }
                }

                SettingsFieldRow(label: "Headline") {
                    TextField("Refuel your focus", text: $style.headline)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsFieldRow(label: "Subtitle") {
                    TextField("Look away and relax your eyes.", text: $style.subtitle)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsFieldRow(label: "Show clock") {
                    Toggle("", isOn: $style.showClock).toggleStyle(.switch).labelsHidden()
                }
            }
            .padding(14)
            .background(OtoSettingsUI.cardFill, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                    .strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(Color.otoSettingsSurface)
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            Group {
                switch style.background {
                case .gradient: style.gradient
                case .solid:    style.baseColor
                case .image:
                    if let img = style.resolvedImage() {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        style.gradient
                    }
                }
            }
            Color.black.opacity(0.28)

            VStack(spacing: 6) {
                Text(style.headline.isEmpty ? "Refuel your focus" : style.headline)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(style.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text("00:30")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            .padding(8)

            if style.showClock {
                VStack {
                    HStack {
                        Text("9:41 AM")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                .strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1)
        }
    }

    // MARK: Image picker

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Prefer a security-scoped bookmark (sandboxed); fall back to a plain
        // bookmark for the non-sandboxed build. Either resolves in
        // BreakScreenStyle.resolvedImage().
        let bookmark = (try? url.bookmarkData(options: [.withSecurityScope]))
            ?? (try? url.bookmarkData())
        guard let bookmark else { return }
        style.imageBookmark = bookmark
        style.background = .image
    }
}
