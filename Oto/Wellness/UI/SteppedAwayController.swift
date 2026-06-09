import AppKit
import SwiftUI

/// A floating, non-activating vibrancy panel that hosts the "Stepped away?"
/// prompt. Uses an `NSVisualEffectView` with `.behindWindow` blending so the
/// panel blends with whatever desktop/app is behind it (lighter over light
/// wallpapers, darker over dark ones), matching LookAway.
@MainActor
final class SteppedAwayController {
    private let manager: BreakManager
    private let store: WellnessStore
    private var panel: NSPanel?
    private var autoDismiss: Task<Void, Never>?

    init(manager: BreakManager, store: WellnessStore) {
        self.manager = manager
        self.store = store
    }

    func present() {
        // Respect the setting + don't interrupt an active break or stack panels.
        guard store.settings.showSteppedAwayDialog,
              store.settings.idleReturnBehavior != .alwaysResume,
              !manager.isOnBreak,
              panel == nil else { return }

        let view = SteppedAwayView(
            intervalMinutes: store.settings.breakIntervalMinutes,
            onStartFresh: { [weak self] in self?.manager.startFreshSession(); self?.dismiss() },
            onKeepGoing: { [weak self] in self?.dismiss() }
        )

        let host = NSHostingView(rootView: AnyView(view))
        host.focusRingType = .none
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true
        blur.autoresizingMask = [.width, .height]
        blur.addSubview(host)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = blur
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        center(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // Auto-dismiss if ignored.
        autoDismiss = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            self?.dismiss()
        }
    }

    func dismiss() {
        autoDismiss?.cancel()
        autoDismiss = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 80   // slightly above center
        ))
    }
}
