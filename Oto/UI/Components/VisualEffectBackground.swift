import SwiftUI
import AppKit

/// SwiftUI wrapper around `NSVisualEffectView` for genuine macOS vibrancy —
/// the translucent, wallpaper-blurring material you can't get from a flat
/// `Color`. Use as a `.background { }`; SwiftUI owns the layout, so we never
/// touch the view's frame (per AppKit-interop guidance).
///
/// For the material to show the desktop behind it, the hosting window must be
/// non-opaque with a clear `backgroundColor` (see `OnboardingWindowController`).
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var isEmphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        // .active keeps the vibrancy lit even when the window isn't key —
        // otherwise the panel turns flat grey the moment focus leaves it.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        view.state = .active
    }
}
