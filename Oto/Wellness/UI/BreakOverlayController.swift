import AppKit
import SwiftUI

/// Borderless full-screen panel for the break overlay. Becomes key so the Skip
/// button / Escape shortcut work, and floats above everything (incl. the menu
/// bar) at `.screenSaver` level.
private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Presents the break overlay across every connected display while
/// `BreakManager` is on a break. Mirrors `SpotlightWindowController`'s
/// NSWindow-lifecycle approach. The SwiftUI `BreakOverlayView` reads the shared
/// `BreakManager` for the live countdown and Skip action; this controller only
/// shows/hides the windows (wired to the manager's `onBreakStart`/`onBreakEnd`).
@MainActor
final class BreakOverlayController {
    private let manager: BreakManager
    private var windows: [BreakOverlayWindow] = []
    private var keyMonitor: Any?
    private var lastEscape: Date?

    init(manager: BreakManager) {
        self.manager = manager
    }

    func show() {
        guard windows.isEmpty else { return }
        let primaryScreen = NSScreen.main
        for screen in NSScreen.screens {
            let isPrimary = (screen == primaryScreen)
            windows.append(makeWindow(for: screen, isPrimary: isPrimary))
        }
        // Bring the app forward so the primary overlay can take key and receive
        // the Escape/Skip interaction.
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        installEscMonitor()

        // Auto-lock the Mac the moment the break starts, if the user opted in.
        if manager.lockOnBreakStart { lockScreen() }
    }

    func hide() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        lastEscape = nil
        for win in windows {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                win.animator().alphaValue = 0
            }, completionHandler: { [weak win] in
                win?.orderOut(nil)
            })
        }
        windows.removeAll()
    }

    // MARK: Esc-to-skip (double press)

    private func installEscMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event }  // 53 = Escape
            Task { @MainActor in self.handleEscape() }
            return nil  // swallow Esc so it doesn't beep
        }
    }

    private func handleEscape() {
        guard manager.doubleEscapeShouldSkip else { return }
        let now = Date()
        if let last = lastEscape, now.timeIntervalSince(last) < 1.5 {
            lastEscape = nil
            manager.skipBreak()
        } else {
            lastEscape = now
        }
    }

    // MARK: Screen lock

    /// Locks the Mac via the private login-framework entry point, with a
    /// display-sleep fallback (which locks too when "require password after
    /// sleep" is set).
    private func lockScreen() {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        if let handle = dlopen(path, RTLD_NOW) {
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                typealias LockFn = @convention(c) () -> Int32
                _ = unsafeBitCast(sym, to: LockFn.self)()
            }
            dlclose(handle)
        } else {
            // Fallback: sleep the displays.
            let task = Process()
            task.launchPath = "/usr/bin/pmset"
            task.arguments = ["displaysleepnow"]
            try? task.run()
        }
    }

    private func makeWindow(for screen: NSScreen, isPrimary: Bool) -> BreakOverlayWindow {
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.frame = NSRect(origin: .zero, size: screen.frame.size)
        blur.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: AnyView(
            BreakOverlayView(isPrimary: isPrimary, onLockScreen: { [weak self] in self?.lockScreen() })
                .environment(manager)
        ))
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        host.focusRingType = .none
        blur.addSubview(host)

        let win = BreakOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.contentView = blur
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.ignoresMouseEvents = !isPrimary
        win.setFrame(screen.frame, display: true)
        win.alphaValue = 0
        win.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            win.animator().alphaValue = 1
        }
        return win
    }
}
