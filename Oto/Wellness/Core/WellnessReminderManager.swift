import Foundation

/// Receives reminders for presentation. Implemented by `ReminderOverlayController`
/// (UI side) and set on `WellnessReminderManager` by `AppState`, keeping this
/// manager free of AppKit/SwiftUI.
@MainActor
protocol ReminderPresenting: AnyObject {
    func presentReminder(
        kind: WellnessReminderManager.ReminderKind,
        style: ReminderStyle,
        dim: Bool,
        hideInRecording: Bool
    )
}

/// Schedules the posture and blink wellness reminders at their configured
/// cadences and delivers them as floating on-screen overlays (LookAway-style).
/// Suppressed while a break is active; suppressed during Smart Pause unless the
/// user opted to keep reminders running then.
@MainActor
final class WellnessReminderManager {
    private let store: WellnessStore
    private let breaks: BreakManager

    private var postureTimer: Timer?
    private var blinkTimer: Timer?

    /// The overlay presenter (wired by AppState).
    weak var presenter: ReminderPresenting?

    /// Reported when a reminder is actually shown, for stats (wired by AppState).
    var onReminderShown: ((ReminderKind) -> Void)?

    enum ReminderKind { case posture, blink }

    init(store: WellnessStore, breaks: BreakManager) {
        self.store = store
        self.breaks = breaks
    }

    func start() { reschedule() }

    /// Re-arm both timers from current settings. A reminder runs only when it's
    /// enabled *and* has a non-zero cadence.
    func reschedule() {
        postureTimer?.invalidate(); postureTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil

        let s = store.settings
        if s.postureReminderEnabled, s.postureReminderMinutes > 0 {
            postureTimer = makeTimer(minutes: s.postureReminderMinutes) { [weak self] in
                self?.fire(.posture)
            }
        }
        if s.blinkReminderEnabled, s.blinkReminderMinutes > 0 {
            blinkTimer = makeTimer(minutes: s.blinkReminderMinutes) { [weak self] in
                self?.fire(.blink)
            }
        }
    }

    /// Called when a break ends — re-arm the cadences if the user wants the
    /// reminder clocks to restart after each break.
    func handleBreakEnded() {
        guard store.settings.resetReminderTimersAfterBreak else { return }
        reschedule()
    }

    /// Show a reminder immediately (used by the settings "preview" buttons),
    /// bypassing the enable/cadence gates.
    func preview(_ kind: ReminderKind) {
        let s = store.settings
        let style = kind == .posture ? s.postureStyle : s.blinkStyle
        presenter?.presentReminder(
            kind: kind, style: style,
            dim: s.dimScreenForReminders,
            hideInRecording: s.hideRemindersInScreenRecording
        )
    }

    private func makeTimer(minutes: Int, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: TimeInterval(minutes * 60), repeats: true) { _ in
            Task { @MainActor in block() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func fire(_ kind: ReminderKind) {
        let s = store.settings
        // Never stack a reminder onto a break screen.
        guard !breaks.isOnBreak else { return }
        // During Smart Pause, only fire if the user opted to keep them active.
        if breaks.isPaused, !s.remindersActiveDuringSmartPause { return }

        let style = kind == .posture ? s.postureStyle : s.blinkStyle
        presenter?.presentReminder(
            kind: kind, style: style,
            dim: s.dimScreenForReminders,
            hideInRecording: s.hideRemindersInScreenRecording
        )
        onReminderShown?(kind)
    }
}
