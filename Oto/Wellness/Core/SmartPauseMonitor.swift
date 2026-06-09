import AppKit
import CoreGraphics

/// Freezes the focus timer when the user clearly isn't engaged, so a break never
/// counts down (or fires) while they're away or busy elsewhere. Signals, each
/// individually gated by settings:
///   • user idle beyond a threshold (no keyboard/mouse activity)
///   • screen locked / display asleep
///   • an activity source is active (meetings, video, calendar, deep-focus
///     apps, gaming, screen recording — via `SmartPauseSourceDetector`)
///
/// After the last signal clears it keeps the session paused for a configurable
/// cooldown. It also installs `BreakManager.extraBreakGate` for the "don't break
/// while typing" rule. (The "Stepped Away?" return-from-idle prompt is handled
/// separately by `ScreenUsageMonitor` → `SteppedAwayController`.)
///
/// Drives `BreakManager.setPaused(_:)`. A 5-second poll covers idle/source
/// cases; lock/sleep flip instantly off `NSWorkspace` / distributed notifications.
@MainActor
final class SmartPauseMonitor {
    private let store: WellnessStore
    private let breaks: BreakManager
    private let detector: SmartPauseSourceDetector

    private var poll: Timer?
    private var screenLocked = false
    private var displayAsleep = false
    private var observers: [NSObjectProtocol] = []

    /// When the most recent active pause signal was last seen (drives cooldown).
    private var lastActivePauseAt: Date?

    /// Event types whose "seconds since last" we min over to approximate
    /// "seconds since any user input" (CGEventType has no reliable "any" case).
    private static let inputEventTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .keyUp,
        .scrollWheel, .flagsChanged, .otherMouseDown,
    ]

    init(store: WellnessStore, breaks: BreakManager) {
        self.store = store
        self.breaks = breaks
        self.detector = SmartPauseSourceDetector(store: store)
    }

    func start() {
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleep = true; self?.recompute() }
        })
        observers.append(ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleep = false; self?.recompute() }
        })

        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.screenLocked = true; self?.recompute() }
        })
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.screenLocked = false; self?.recompute() }
        })

        // "Don't show breaks while typing/dragging/dictating": hold the break
        // at the threshold until input goes quiet.
        breaks.extraBreakGate = { [weak self] in
            guard let self else { return true }
            guard self.store.settings.suppressBreaksWhileTyping else { return true }
            return !self.detector.isInputBusy()
        }

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
        recompute()
    }

    func reschedule() { recompute() }

    private var idleSeconds: TimeInterval {
        Self.inputEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    private func recompute() {
        let s = store.settings
        guard s.smartPauseEnabled else {
            breaks.setPaused(false)
            lastActivePauseAt = nil
            return
        }

        let idlePaused = idleSeconds >= TimeInterval(s.idlePauseSeconds)
        let lockPaused = s.pauseOnScreenLock && screenLocked
        let sleepPaused = s.pauseOnDisplaySleep && displayAsleep
        let sourcePaused = detector.isPausedBySource()
        let active = idlePaused || lockPaused || sleepPaused || sourcePaused

        if active {
            lastActivePauseAt = Date()
            breaks.setPaused(true)
        } else if let last = lastActivePauseAt,
                  s.smartPauseCooldownSeconds > 0,
                  Date().timeIntervalSince(last) < TimeInterval(s.smartPauseCooldownSeconds) {
            breaks.setPaused(true)   // hold through the cooldown window
        } else {
            breaks.setPaused(false)
        }
    }
}
