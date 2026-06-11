import AppKit
import SwiftUI

/// Hosts the first-run onboarding in a standard titled window (traffic-light
/// chrome, like LookAway's setup), as opposed to the borderless spotlight panel
/// the audio first-run used. Centered, fixed-size, single instance.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let host = NSHostingView(rootView: AnyView(
            OnboardingView()
                .environment(state)
        ))
        host.focusRingType = .none

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.contentView = host
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.title = "Welcome to Oto"
        // Non-opaque + clear background so the `.behindWindow` vibrancy material
        // can blur the desktop through the window instead of a solid fill.
        win.isOpaque = false
        win.backgroundColor = .clear
        // Pin dark so the translucent HUD material + light text read correctly
        // regardless of the system appearance (matches the reference).
        win.appearance = NSAppearance(named: .darkAqua)
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }
}
