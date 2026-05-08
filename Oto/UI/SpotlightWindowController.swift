import AppKit
import SwiftUI

/// Borderless transparent window used for Oto's main panel. Becomes key/main
/// so SwiftUI inputs (toggles, sheets, menus) work normally.
final class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

    private init() {}

    func install<Root: View>(rootView: Root) {
        if window != nil { return }

        let size = preferredSize(for: currentVisibleFrame())
        let host = NSHostingView(rootView: AnyView(
            rootView
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.light)
        ))
        host.frame = NSRect(origin: .zero, size: size)
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
        win.appearance = NSAppearance(named: .aqua)
        self.window = win

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
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
        NSSize(
            width: min(820, max(720, visibleFrame.width - 64)),
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
