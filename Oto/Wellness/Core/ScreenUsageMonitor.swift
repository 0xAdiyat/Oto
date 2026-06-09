import AppKit
import CoreGraphics

/// Samples active screen time, the current unbroken focus stretch, per-app
/// usage, and "natural breaks" (stepping away long enough to count as a rest).
/// Feeds `WellnessStatsStore`, which powers the Stats tab.
///
/// Activity is inferred from input idle time (no extra permissions). A tick is
/// "active" when the user has touched the keyboard/mouse recently; a long idle
/// gap finalizes the current stretch and logs a natural break.
@MainActor
final class ScreenUsageMonitor {
    private let store: WellnessStore
    private let stats: WellnessStatsStore

    private var timer: Timer?
    private var currentStretchSeconds = 0
    private var naturalBreakCounted = false

    /// Fired when the user returns to the keyboard after being away long enough
    /// to count as a natural break — drives the "Stepped away?" prompt.
    var onReturnedFromAway: (() -> Void)?

    /// Sampling cadence. Each active tick adds this many seconds.
    private let tickInterval = 3
    /// Idle under this ⇒ the user is actively using the Mac.
    private let activeThreshold: TimeInterval = 30

    private static let inputEventTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .keyUp,
        .scrollWheel, .flagsChanged, .otherMouseDown,
    ]

    init(store: WellnessStore, stats: WellnessStatsStore) {
        self.store = store
        self.stats = stats
    }

    func start() {
        let timer = Timer(timeInterval: TimeInterval(tickInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Called when a break is taken via the overlay — ends the current stretch.
    func noteBreakTaken() {
        stats.endStretch(seconds: currentStretchSeconds)
        currentStretchSeconds = 0
        naturalBreakCounted = false
    }

    private var idleSeconds: TimeInterval {
        Self.inputEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    private var naturalBreakThreshold: TimeInterval {
        TimeInterval(max(120, store.settings.breakLengthSeconds))
    }

    private func tick() {
        let idle = idleSeconds
        if idle < activeThreshold {
            // Just returned from a long-enough idle gap — offer a fresh session.
            if naturalBreakCounted { onReturnedFromAway?() }
            naturalBreakCounted = false
            currentStretchSeconds += tickInterval
            let app = NSWorkspace.shared.frontmostApplication
            let bid = app?.bundleIdentifier ?? "unknown"
            // Don't count Oto's own break overlay / popover as usage.
            guard bid != Bundle.main.bundleIdentifier else { return }
            stats.addScreenTime(
                seconds: tickInterval,
                bundleID: bid,
                appName: app?.localizedName ?? "Unknown",
                currentStretchSeconds: currentStretchSeconds
            )
        } else if idle >= naturalBreakThreshold, !naturalBreakCounted {
            naturalBreakCounted = true
            stats.endStretch(seconds: currentStretchSeconds)
            currentStretchSeconds = 0
            stats.recordNaturalBreak()
        }
    }
}
