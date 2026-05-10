import AppKit
import SwiftUI

/// Borderless transparent window used for Oto's main panel. Becomes key/main
/// so SwiftUI inputs (toggles, sheets, menus) work normally.
final class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Notification.Name {
    /// Posted by `SpotlightWindowController` whenever the main window is
    /// brought on screen via `present()`. Use this to drive the spotlight
    /// reveal animation on each open instead of `didBecomeActiveNotification`,
    /// which fires for every internal focus event.
    static let spotlightWindowDidPresent = Notification.Name("Oto.spotlightWindowDidPresent")
}

/// Owns the borderless main window and its presentation lifecycle.
/// Mirrors media-downloader's AppDelegate pattern (presentWindow / orderOut on
/// resign / re-center on each activation).
@MainActor
final class SpotlightWindowController {
    static let shared = SpotlightWindowController()

    private var window: SpotlightWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var resignObserver: NSObjectProtocol?

    /// While true, the `didResignActive` auto-hide path is a no-op. Set this
    /// from MainWindowView whenever an in-panel sheet (Devices, Add Rule, …)
    /// is showing — opening some sheets briefly resigns app-active state
    /// (system permission alerts, AppKit-bridged controls), which would
    /// otherwise hide the entire window mid-interaction.
    var suppressAutoHide: Bool = false

    private init() {}

    func install<Root: View>(rootView: Root) {
        if window != nil { return }

        let size = preferredSize(for: currentVisibleFrame())
        let host = NSHostingView(rootView: AnyView(
            rootView
                .frame(width: size.width, height: size.height)
        ))
        host.frame = NSRect(origin: .zero, size: size)
        // Suppress AppKit's exterior focus ring around the hosting view —
        // otherwise a faint rounded-rect outline appears around the entire
        // panel whenever the borderless window becomes key.
        host.focusRingType = .none
        self.hostingView = host

        let win = SpotlightWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.contentView = host
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovableByWindowBackground = true
        win.level = .normal
        win.collectionBehavior = [.moveToActiveSpace]
        win.title = "Oto"
        self.window = win

        // Auto-hide only when the user truly switches to another app. Two
        // signals are checked together after a 250ms debounce:
        //   • `NSApp.isActive` — false means the app stayed inactive past the
        //     transient focus blips that AppKit fires during normal clicks
        //     in a borderless window.
        //   • frontmost app's bundle id ≠ ours — confirms another app
        //     genuinely owns the foreground.
        // Either-or isn't enough on its own: SwiftUI focus dance can leave
        // `isActive` false even while we're still frontmost, and the
        // frontmost app can briefly switch during system events without
        // really meaning we lost focus. Requiring both eliminates the
        // false-positive that was hiding the window mid-tab-click.
        let myBundleId = Bundle.main.bundleIdentifier
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                // Sheets / system permission alerts can briefly steal focus.
                // Skip auto-hide entirely while a sheet owns the panel.
                guard !SpotlightWindowController.shared.suppressAutoHide else { return }
                guard !NSApp.isActive else { return }
                let frontId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                guard frontId != myBundleId else { return }
                SpotlightWindowController.shared.hide()
            }
        }
    }

    func present(activate: Bool) {
        guard let win = window else { return }
        center(win)
        win.makeKeyAndOrderFront(nil)
        if activate {
            NSApp.activate()
        }
        // Drive the reveal animation off this single deterministic event
        // rather than the noisy NSApp.didBecomeActiveNotification.
        NotificationCenter.default.post(name: .spotlightWindowDidPresent, object: nil)
    }

    func toggle() {
        guard let win = window else { return }
        if win.isVisible {
            hide()
        } else {
            present(activate: true)
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - Geometry

    private func currentVisibleFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private func preferredSize(for visibleFrame: NSRect) -> NSSize {
        // Hug the cards: pillWidth (680) + 16pt margin on each side = 712.
        // On tiny screens fall back to whatever fits with at least a 16pt
        // outer margin so the window never crops the cards.
        let target: CGFloat = OtoUI.pillWidth + 32
        let width = min(target, max(target - 32, visibleFrame.width - 32))
        return NSSize(
            width: width,
            height: min(820, max(620, visibleFrame.height - 80))
        )
    }

    private func center(_ win: NSWindow) {
        let visible = currentVisibleFrame()
        let size = win.frame.size
        win.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }
}
