import Foundation
import Observation

/// Drives the screen-break cycle — the Wellbeing-domain analog of the audio
/// `RuleEngine`. A single 1-second tick advances a small state machine:
///
///   focusing → (pre-break warning) → onBreak → focusing → …
///
/// `@Observable` so SwiftUI (menu-bar label, Focus popover, break overlay) reads
/// `secondsUntilBreak` / `breakSecondsRemaining` / `isOnBreak` directly and stays
/// live. Side effects that aren't view state (showing the overlay window, playing
/// sounds, recording stats) are delivered through closure hooks that `AppState`
/// wires up, keeping this type free of UI/AppKit dependencies.
@Observable
@MainActor
final class BreakManager {
    enum Phase: Equatable {
        case idle       // breaks disabled
        case focusing
        case onBreak
    }

    private(set) var phase: Phase = .focusing
    /// Seconds of focus remaining before the next break.
    private(set) var secondsUntilBreak: Int = 0
    /// Seconds left in the current break (only meaningful while `.onBreak`).
    private(set) var breakSecondsRemaining: Int = 0
    /// Total length of the current break, for progress display.
    private(set) var currentBreakLength: Int = 0
    /// Seconds focused in the current cycle (resets after each break).
    private(set) var focusElapsedSeconds: Int = 0
    /// True while Smart Pause has frozen focus accrual.
    private(set) var isPaused: Bool = false
    /// Whether the current break is a "long break" (per the long-break cadence).
    private(set) var isLongBreak: Bool = false

    var isOnBreak: Bool { phase == .onBreak }

    // MARK: Side-effect hooks (wired by AppState)

    /// Show the full-screen break overlay.
    @ObservationIgnored var onBreakStart: (() -> Void)?
    /// Tear down the break overlay.
    @ObservationIgnored var onBreakEnd: (() -> Void)?
    /// Fire the "break coming up" nudge (once per cycle).
    @ObservationIgnored var onPreBreakWarning: (() -> Void)?
    /// Report a finished break for stats: `completed` is false when skipped.
    @ObservationIgnored var onBreakFinished: ((_ completed: Bool, _ focusedSeconds: Int) -> Void)?
    /// Report a snooze (delay) for stats.
    @ObservationIgnored var onSnooze: ((_ minutes: Int) -> Void)?
    /// Optional gate consulted at the moment a break would begin. Return false
    /// to hold the break (e.g. Smart Pause's "don't break while typing"). The
    /// focus timer stays at the threshold and the break fires once it returns
    /// true. Defaults to "allow" when unset.
    @ObservationIgnored var extraBreakGate: (() -> Bool)?

    private let store: WellnessStore
    private var ticker: Timer?
    private var cycleLengthSeconds: Int = 0   // grows when the user delays
    private var warningFired = false
    /// Count of breaks begun since launch, for the long-break cadence.
    private var breaksBegun = 0

    init(store: WellnessStore) {
        self.store = store
    }

    private var settings: WellnessSettings { store.settings }

    // MARK: Lifecycle

    func start() {
        reschedule()
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    /// Re-read settings and reset the current focus cycle. Called on launch and
    /// whenever `WellnessSettings` changes.
    func reschedule() {
        guard settings.breaksEnabled else {
            phase = .idle
            secondsUntilBreak = 0
            return
        }
        if phase == .onBreak { return }   // don't interrupt an active break
        phase = .focusing
        cycleLengthSeconds = max(1, Int(settings.breakInterval))
        focusElapsedSeconds = min(focusElapsedSeconds, cycleLengthSeconds)
        warningFired = false
        recomputeRemaining()
    }

    // MARK: Smart Pause

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    // MARK: User actions

    func startBreakNow() {
        guard phase == .focusing else { return }
        beginBreak()
    }

    /// Reset the focus cycle to a full fresh session (used by the "Stepped
    /// away?" prompt when the user opts to start over after a break away).
    func startFreshSession() {
        guard settings.breaksEnabled else { return }
        phase = .focusing
        cycleLengthSeconds = max(1, Int(settings.breakInterval))
        focusElapsedSeconds = 0
        warningFired = false
        recomputeRemaining()
    }

    /// Push the next break out by `minutes` (the +1m / +5m / +15m controls).
    func delay(minutes: Int) {
        guard phase == .focusing else { return }
        cycleLengthSeconds += minutes * 60
        warningFired = false
        recomputeRemaining()
        onSnooze?(minutes)
    }

    /// End the current break early. Counts as a skipped break.
    func skipBreak() {
        guard phase == .onBreak else { return }
        endBreak(completed: false)
    }

    /// End the current break normally (auto-dismiss when the timer elapses, or
    /// an explicit "I'm done").
    func endBreak() {
        guard phase == .onBreak else { return }
        endBreak(completed: true)
    }

    // MARK: Tick

    private func tick() {
        switch phase {
        case .idle:
            return
        case .focusing:
            guard !isPaused else { return }
            focusElapsedSeconds += 1
            recomputeRemaining()
            if !warningFired,
               settings.preBreakWarningSeconds > 0,
               secondsUntilBreak <= settings.preBreakWarningSeconds {
                warningFired = true
                onPreBreakWarning?()
            }
            if secondsUntilBreak <= 0 {
                // Only fire within office hours and when no extra gate (e.g.
                // active typing) holds it; otherwise hold at the threshold
                // until the window opens / input goes quiet.
                if withinOfficeHours && (extraBreakGate?() ?? true) {
                    beginBreak()
                } else {
                    focusElapsedSeconds = cycleLengthSeconds
                }
            }
        case .onBreak:
            breakSecondsRemaining -= 1
            if breakSecondsRemaining <= 0 {
                endBreak(completed: true)
            }
        }
    }

    private func recomputeRemaining() {
        secondsUntilBreak = max(0, cycleLengthSeconds - focusElapsedSeconds)
    }

    private func beginBreak() {
        breaksBegun += 1
        isLongBreak = settings.longBreaksEnabled
            && settings.longBreakEvery > 0
            && breaksBegun % settings.longBreakEvery == 0
        phase = .onBreak
        currentBreakLength = isLongBreak
            ? max(1, settings.longBreakMinutes * 60)
            : max(1, settings.breakLengthSeconds)
        breakSecondsRemaining = currentBreakLength
        onBreakStart?()
    }

    /// Whether the current time falls inside the office-hours window (always
    /// true when office hours are disabled). Handles windows that wrap midnight.
    var withinOfficeHours: Bool {
        guard settings.officeHoursEnabled else { return true }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let start = settings.officeHoursStartMinute
        let end = settings.officeHoursEndMinute
        if start <= end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end   // wraps past midnight
    }

    /// 0…1 progress through the current break (0 at start, 1 at end).
    var breakProgress: Double {
        guard currentBreakLength > 0 else { return 0 }
        return 1 - (Double(breakSecondsRemaining) / Double(currentBreakLength))
    }

    var allowsSkipping: Bool { settings.enforcement.allowsSkip }
    /// Seconds into a break before the Skip control unlocks (Balanced mode).
    var skipUnlockSeconds: Int { settings.enforcement.skipUnlockSeconds }
    /// Seconds elapsed in the current break.
    var breakElapsedSeconds: Int { max(0, currentBreakLength - breakSecondsRemaining) }
    /// Whether the Skip control should be enabled right now (respects the
    /// Balanced "skip after a pause" unlock delay and Hardcore's no-skip rule).
    var canSkipNow: Bool { allowsSkipping && breakElapsedSeconds >= skipUnlockSeconds }
    /// Whether a double-Esc on the break screen should skip (per settings).
    var doubleEscapeShouldSkip: Bool {
        settings.doubleEscapeAction == .skipBreak && allowsSkipping
    }

    /// Threshold (seconds) under which an in-progress break is "nearly done".
    private var earlyEndThreshold: Int { max(5, min(15, currentBreakLength / 4)) }
    /// Whether the "End break" early control should be offered right now.
    var allowsEndEarly: Bool {
        settings.endBreakEarlyIfNearlyDone
            && phase == .onBreak
            && breakSecondsRemaining <= earlyEndThreshold
            && breakSecondsRemaining > 0
    }

    /// End a nearly-finished break early. Counts as completed (not skipped).
    func endBreakEarly() {
        guard allowsEndEarly else { return }
        endBreak(completed: true)
    }

    // MARK: Overlay passthroughs (read by BreakOverlayView / Controller)

    var screenStyle: BreakScreenStyle { settings.breakScreenStyle }
    var lockOnBreakStart: Bool { settings.lockMacOnBreakStart }
    var longBreakLabel: String { "Long break · \(WellnessSettings.durationLabel(seconds: currentBreakLength))" }

    private func endBreak(completed: Bool) {
        let focused = focusElapsedSeconds
        phase = .focusing
        breakSecondsRemaining = 0
        focusElapsedSeconds = 0
        cycleLengthSeconds = max(1, Int(settings.breakInterval))
        warningFired = false
        recomputeRemaining()
        onBreakEnd?()
        onBreakFinished?(completed, focused)
    }

    // MARK: Display helpers

    /// Compact label for the menu-bar item, e.g. "27m" or "45s".
    var menuBarCountdown: String {
        guard phase != .idle else { return "—" }
        if isOnBreak { return Self.clock(breakSecondsRemaining) }
        if secondsUntilBreak >= 60 {
            let mins = Int(ceil(Double(secondsUntilBreak) / 60.0))
            return "\(mins)m"
        }
        return "\(secondsUntilBreak)s"
    }

    /// Menu-bar countdown formatted per the user's chosen timer style.
    func menuBarCountdown(style: WellnessSettings.MenuBarTimerStyle) -> String {
        guard phase != .idle else { return "—" }
        let seconds = isOnBreak ? breakSecondsRemaining : secondsUntilBreak
        switch style {
        case .minutes:
            return menuBarCountdown   // existing "27m" / "45s"
        case .minutesSeconds:
            return Self.clock(seconds)
        case .compact:
            return seconds >= 60 ? "\(Int(ceil(Double(seconds) / 60.0)))" : "\(seconds)"
        }
    }

    /// MM:SS clock used in the popover and overlay.
    var clockUntilBreak: String { Self.clock(secondsUntilBreak) }
    var clockBreakRemaining: String { Self.clock(breakSecondsRemaining) }

    var focusElapsedLabel: String {
        let m = focusElapsedSeconds / 60
        let s = focusElapsedSeconds % 60
        if m == 0 { return "\(s) sec\(s == 1 ? "" : "s")" }
        return "\(m) min\(m == 1 ? "" : "s")"
    }

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
