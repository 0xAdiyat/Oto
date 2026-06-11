import AppKit
import SwiftUI

/// Presents the transient posture / blink reminder overlays. A non-activating,
/// click-through panel positioned per `ReminderStyle.Position` and sized per
/// `.Size`, with an optional full-screen dim behind it. Auto-dismisses after a
/// few seconds. Mirrors `BreakOverlayController`'s windowing, but lightweight
/// (no key window, no input capture). Conforms to `ReminderPresenting` so
/// `WellnessReminderManager` stays UI-free.
@MainActor
final class ReminderOverlayController: ReminderPresenting {
    private var panel: NSPanel?
    private var dimWindows: [NSWindow] = []
    private var dismissWork: DispatchWorkItem?

    func presentReminder(
        kind: WellnessReminderManager.ReminderKind,
        style: ReminderStyle,
        dim: Bool,
        hideInRecording: Bool
    ) {
        dismiss(animated: false)   // replace any in-flight reminder

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.frame else { return }

        if dim { showDim(in: frame, hideInRecording: hideInRecording) }

        let dimension = style.size.dimension
        let size = CGSize(width: dimension, height: dimension * 0.7)
        let origin = style.position.origin(for: size, in: frame, inset: 40)

        let host = NSHostingView(rootView: AnyView(
            ReminderOverlayView(kind: kind, size: style.size)
                .frame(width: size.width, height: size.height)
        ))
        host.focusRingType = .none
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        if hideInRecording { panel.sharingType = .none }
        panel.alphaValue = 0
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        if let name = style.soundName, let sound = NSSound(named: name) {
            sound.play()
        }

        // Blink is a quick nudge; posture lingers a touch longer.
        let seconds: TimeInterval = (kind == .blink) ? 3.5 : 6
        let work = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func showDim(in frame: CGRect, hideInRecording: Bool) {
        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = NSColor.black.withAlphaComponent(0.22)
            win.hasShadow = false
            win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if hideInRecording { win.sharingType = .none }
            win.alphaValue = 0
            win.setFrame(screen.frame, display: true)
            win.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                win.animator().alphaValue = 1
            }
            dimWindows.append(win)
        }
    }

    func dismiss(animated: Bool) {
        dismissWork?.cancel()
        dismissWork = nil
        let toClose = dimWindows + [panel].compactMap { $0 }
        panel = nil
        dimWindows.removeAll()
        guard animated else {
            toClose.forEach { $0.orderOut(nil) }
            return
        }
        for win in toClose {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                win.animator().alphaValue = 0
            }, completionHandler: { win.orderOut(nil) })
        }
    }
}
