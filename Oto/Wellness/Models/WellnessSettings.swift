import Foundation

/// All user-tunable preferences for the Wellbeing domain (screen breaks,
/// posture/blink reminders, Smart Pause, sounds, menu-bar presentation).
/// Mirrors the role `QuietHoursSettings` plays for the audio domain: a single
/// `Codable` value owned by a store, persisted as JSON to `UserDefaults`.
///
/// Values intentionally map to the discrete presets shown in the LookAway-style
/// onboarding and settings chips (e.g. break interval ∈ {10,20,30,45} min) but
/// the engine treats them as plain numbers, so any value persists cleanly.
///
/// **Schema evolution:** new fields are added with inline defaults and decoded
/// via the custom `init(from:)` below using `decodeIfPresent ?? default`. Old
/// `Oto.wellness.settings.v1` blobs keep loading unchanged — no migration, per
/// the additive-Codable rule in `agent-os/standards/global/state-management.md`.
struct WellnessSettings: Codable, Hashable {
    // MARK: Screen breaks

    /// Minutes of focus before a break is triggered. Onboarding presets: 10/20/30/45.
    var breakIntervalMinutes: Int
    /// How long the break overlay stays up. Onboarding presets: 15/30/45/60 s.
    var breakLengthSeconds: Int
    /// Seconds before a break to surface the "break coming up" nudge. 0 disables it.
    var preBreakWarningSeconds: Int
    /// Whether breaks run at all. When false the focus timer never fires.
    var breaksEnabled: Bool
    /// Allow ending a break a little early once it's almost over.
    var endBreakEarlyIfNearlyDone: Bool = false
    /// Lock the Mac automatically the moment a break starts.
    var lockMacOnBreakStart: Bool = false
    /// Visual style for the full-screen break overlay (Customize break screen).
    var breakScreenStyle: BreakScreenStyle = .default

    // MARK: Break enforcement

    /// How strictly breaks are enforced (Casual / Balanced / Hardcore).
    var enforcement: BreakEnforcement
    /// Snoozes (delays) allowed within one focus session. -1 == no limit.
    var snoozesPerSession: Int
    /// Snoozes allowed per calendar day. -1 == no limit.
    var snoozesPerDay: Int
    /// Show a "snoozes remaining" hint after snoozing.
    var showSnoozesRemaining: Bool
    /// What a double-press of Escape on the break screen does.
    var doubleEscapeAction: DoubleEscapeAction

    // MARK: Long breaks

    var longBreaksEnabled: Bool
    /// Every Nth break is a long break.
    var longBreakEvery: Int
    /// Length of a long break, in minutes.
    var longBreakMinutes: Int

    // MARK: Office hours (breaks only run within this window when enabled)

    var officeHoursEnabled: Bool
    var officeHoursStartMinute: Int   // 0...1439
    var officeHoursEndMinute: Int     // 0...1439

    enum BreakEnforcement: String, Codable, CaseIterable, Hashable {
        case casual     // skip anytime
        case balanced   // skip after a short pause
        case hardcore   // no skips

        var title: String {
            switch self {
            case .casual:   return "Casual"
            case .balanced: return "Balanced"
            case .hardcore: return "Hardcore"
            }
        }
        var subtitle: String {
            switch self {
            case .casual:   return "Skip anytime"
            case .balanced: return "Skip after a pause"
            case .hardcore: return "No skips allowed"
            }
        }
        var allowsSkip: Bool { self != .hardcore }
        /// Seconds the user must wait before Skip unlocks (Balanced only).
        var skipUnlockSeconds: Int { self == .balanced ? 5 : 0 }
    }

    enum DoubleEscapeAction: String, Codable, CaseIterable, Hashable {
        case skipBreak
        case nothing

        var label: String {
            switch self {
            case .skipBreak: return "Skip the break"
            case .nothing:   return "Do nothing"
            }
        }
    }

    // MARK: Wellness reminders (cadence in minutes; 0 == disabled)

    /// Posture-reminder cadence in minutes. 0 means disabled.
    var postureReminderMinutes: Int
    /// Blink-reminder cadence in minutes. 0 means disabled.
    var blinkReminderMinutes: Int
    /// Master enable for the posture reminder (separate from cadence).
    var postureReminderEnabled: Bool = false
    /// Master enable for the blink reminder (separate from cadence).
    var blinkReminderEnabled: Bool = false
    /// Overlay presentation (size / position / sound) for each reminder.
    var postureStyle: ReminderStyle = .posture
    var blinkStyle: ReminderStyle = .blink

    // Common reminder settings
    var dimScreenForReminders: Bool = true
    var remindersActiveDuringSmartPause: Bool = false
    var hideRemindersInScreenRecording: Bool = false
    var resetReminderTimersAfterBreak: Bool = true

    // MARK: Smart Pause

    var smartPauseEnabled: Bool
    /// Pause the focus timer after this many idle seconds (no keyboard/mouse).
    var idlePauseSeconds: Int
    /// Pause while the screen is locked.
    var pauseOnScreenLock: Bool
    /// Pause while the display is asleep.
    var pauseOnDisplaySleep: Bool
    /// Don't surface breaks while actively typing / dragging / dictating.
    var suppressBreaksWhileTyping: Bool = false
    /// Keep the session paused this long after the last pause source clears.
    var smartPauseCooldownSeconds: Int = 60
    /// What to do when returning from a long idle stretch.
    var idleReturnBehavior: IdleReturnBehavior = .automatic
    /// Show the "Stepped Away?" dialog when returning from idle.
    var showSteppedAwayDialog: Bool = true
    /// Which activities automatically pause the focus timer.
    var smartPauseSources: SmartPauseSources = .default

    enum IdleReturnBehavior: String, Codable, CaseIterable, Hashable {
        case automatic     // decide based on idle length
        case ask           // prompt resume vs restart
        case alwaysResume  // always resume the prior session

        var label: String {
            switch self {
            case .automatic:    return "Automatic"
            case .ask:          return "Always ask"
            case .alwaysResume: return "Always resume"
            }
        }
    }

    // MARK: Sounds

    var playBreakStartSound: Bool
    var playBreakEndSound: Bool
    var playReminderSound: Bool

    // MARK: Menu-bar presentation

    /// How the menu-bar item renders the focus countdown.
    var menuBarDisplay: MenuBarDisplay
    /// How the countdown value itself is formatted.
    var menuBarTimerStyle: MenuBarTimerStyle = .minutes

    enum MenuBarDisplay: String, Codable, CaseIterable, Hashable {
        case iconOnly        // just the eye glyph
        case iconAndText     // eye + "27m"
        case textOnly        // "27m"

        var label: String {
            switch self {
            case .iconOnly:    return "Icon only"
            case .iconAndText: return "Icon and text"
            case .textOnly:    return "Text only"
            }
        }
    }

    enum MenuBarTimerStyle: String, Codable, CaseIterable, Hashable {
        case minutes         // "27m"
        case minutesSeconds  // "27:09"
        case compact         // "27"

        var label: String {
            switch self {
            case .minutes:        return "Minutes (27m)"
            case .minutesSeconds: return "MM:SS (27:09)"
            case .compact:        return "Compact (27)"
            }
        }
    }

    // MARK: Screen Score (LookAway-style activity score)

    var screenScoreEnabled: Bool = false
    var screenScoreDisplay: MenuBarDisplay = .iconAndText
    var screenScoreColoredRings: Bool = false

    // MARK: Website usage stats

    /// Browsers the user opted into tracking active-tab usage from.
    var trackedBrowsers: Set<BrowserKind> = []

    // MARK: Default

    static let `default` = WellnessSettings(
        breakIntervalMinutes: 20,
        breakLengthSeconds: 30,
        preBreakWarningSeconds: 60,
        breaksEnabled: true,
        enforcement: .balanced,
        snoozesPerSession: -1,
        snoozesPerDay: -1,
        showSnoozesRemaining: false,
        doubleEscapeAction: .skipBreak,
        longBreaksEnabled: false,
        longBreakEvery: 4,
        longBreakMinutes: 3,
        officeHoursEnabled: false,
        officeHoursStartMinute: 9 * 60,
        officeHoursEndMinute: 17 * 60,
        postureReminderMinutes: 0,
        blinkReminderMinutes: 0,
        smartPauseEnabled: true,
        idlePauseSeconds: 60,
        pauseOnScreenLock: true,
        pauseOnDisplaySleep: true,
        playBreakStartSound: true,
        playBreakEndSound: false,
        playReminderSound: false,
        menuBarDisplay: .iconAndText
    )

    // MARK: Convenience

    var breakInterval: TimeInterval { TimeInterval(breakIntervalMinutes * 60) }
    var breakLength: TimeInterval { TimeInterval(breakLengthSeconds) }

    /// Human label for the upcoming break, e.g. "Short · 30 secs".
    var breakLengthLabel: String {
        let kind = breakLengthSeconds <= 30 ? "Short" : "Long"
        return "\(kind) · \(Self.durationLabel(seconds: breakLengthSeconds))"
    }

    static func durationLabel(seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            return mins == 1 && seconds % 60 == 0 ? "1 min" : "\(mins) min"
        }
        return "\(seconds) secs"
    }
}

// MARK: - Tolerant decoding (additive schema)

extension WellnessSettings {
    /// Decode each field with a default fallback so old persisted blobs (which
    /// lack newer keys) and partial/corrupt blobs both load cleanly. `Encodable`
    /// and `CodingKeys` remain compiler-synthesized.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WellnessSettings.default

        breakIntervalMinutes      = try c.decodeIfPresent(Int.self, forKey: .breakIntervalMinutes) ?? d.breakIntervalMinutes
        breakLengthSeconds        = try c.decodeIfPresent(Int.self, forKey: .breakLengthSeconds) ?? d.breakLengthSeconds
        preBreakWarningSeconds    = try c.decodeIfPresent(Int.self, forKey: .preBreakWarningSeconds) ?? d.preBreakWarningSeconds
        breaksEnabled             = try c.decodeIfPresent(Bool.self, forKey: .breaksEnabled) ?? d.breaksEnabled
        endBreakEarlyIfNearlyDone = try c.decodeIfPresent(Bool.self, forKey: .endBreakEarlyIfNearlyDone) ?? d.endBreakEarlyIfNearlyDone
        lockMacOnBreakStart       = try c.decodeIfPresent(Bool.self, forKey: .lockMacOnBreakStart) ?? d.lockMacOnBreakStart
        breakScreenStyle          = try c.decodeIfPresent(BreakScreenStyle.self, forKey: .breakScreenStyle) ?? d.breakScreenStyle

        enforcement               = try c.decodeIfPresent(BreakEnforcement.self, forKey: .enforcement) ?? d.enforcement
        snoozesPerSession         = try c.decodeIfPresent(Int.self, forKey: .snoozesPerSession) ?? d.snoozesPerSession
        snoozesPerDay             = try c.decodeIfPresent(Int.self, forKey: .snoozesPerDay) ?? d.snoozesPerDay
        showSnoozesRemaining      = try c.decodeIfPresent(Bool.self, forKey: .showSnoozesRemaining) ?? d.showSnoozesRemaining
        doubleEscapeAction        = try c.decodeIfPresent(DoubleEscapeAction.self, forKey: .doubleEscapeAction) ?? d.doubleEscapeAction

        longBreaksEnabled         = try c.decodeIfPresent(Bool.self, forKey: .longBreaksEnabled) ?? d.longBreaksEnabled
        longBreakEvery            = try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? d.longBreakEvery
        longBreakMinutes          = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes

        officeHoursEnabled        = try c.decodeIfPresent(Bool.self, forKey: .officeHoursEnabled) ?? d.officeHoursEnabled
        officeHoursStartMinute    = try c.decodeIfPresent(Int.self, forKey: .officeHoursStartMinute) ?? d.officeHoursStartMinute
        officeHoursEndMinute      = try c.decodeIfPresent(Int.self, forKey: .officeHoursEndMinute) ?? d.officeHoursEndMinute

        postureReminderMinutes    = try c.decodeIfPresent(Int.self, forKey: .postureReminderMinutes) ?? d.postureReminderMinutes
        blinkReminderMinutes      = try c.decodeIfPresent(Int.self, forKey: .blinkReminderMinutes) ?? d.blinkReminderMinutes
        postureReminderEnabled    = try c.decodeIfPresent(Bool.self, forKey: .postureReminderEnabled) ?? d.postureReminderEnabled
        blinkReminderEnabled      = try c.decodeIfPresent(Bool.self, forKey: .blinkReminderEnabled) ?? d.blinkReminderEnabled
        postureStyle              = try c.decodeIfPresent(ReminderStyle.self, forKey: .postureStyle) ?? d.postureStyle
        blinkStyle                = try c.decodeIfPresent(ReminderStyle.self, forKey: .blinkStyle) ?? d.blinkStyle
        dimScreenForReminders     = try c.decodeIfPresent(Bool.self, forKey: .dimScreenForReminders) ?? d.dimScreenForReminders
        remindersActiveDuringSmartPause = try c.decodeIfPresent(Bool.self, forKey: .remindersActiveDuringSmartPause) ?? d.remindersActiveDuringSmartPause
        hideRemindersInScreenRecording  = try c.decodeIfPresent(Bool.self, forKey: .hideRemindersInScreenRecording) ?? d.hideRemindersInScreenRecording
        resetReminderTimersAfterBreak   = try c.decodeIfPresent(Bool.self, forKey: .resetReminderTimersAfterBreak) ?? d.resetReminderTimersAfterBreak

        smartPauseEnabled         = try c.decodeIfPresent(Bool.self, forKey: .smartPauseEnabled) ?? d.smartPauseEnabled
        idlePauseSeconds          = try c.decodeIfPresent(Int.self, forKey: .idlePauseSeconds) ?? d.idlePauseSeconds
        pauseOnScreenLock         = try c.decodeIfPresent(Bool.self, forKey: .pauseOnScreenLock) ?? d.pauseOnScreenLock
        pauseOnDisplaySleep       = try c.decodeIfPresent(Bool.self, forKey: .pauseOnDisplaySleep) ?? d.pauseOnDisplaySleep
        suppressBreaksWhileTyping = try c.decodeIfPresent(Bool.self, forKey: .suppressBreaksWhileTyping) ?? d.suppressBreaksWhileTyping
        smartPauseCooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .smartPauseCooldownSeconds) ?? d.smartPauseCooldownSeconds
        idleReturnBehavior        = try c.decodeIfPresent(IdleReturnBehavior.self, forKey: .idleReturnBehavior) ?? d.idleReturnBehavior
        showSteppedAwayDialog     = try c.decodeIfPresent(Bool.self, forKey: .showSteppedAwayDialog) ?? d.showSteppedAwayDialog
        smartPauseSources         = try c.decodeIfPresent(SmartPauseSources.self, forKey: .smartPauseSources) ?? d.smartPauseSources

        playBreakStartSound       = try c.decodeIfPresent(Bool.self, forKey: .playBreakStartSound) ?? d.playBreakStartSound
        playBreakEndSound         = try c.decodeIfPresent(Bool.self, forKey: .playBreakEndSound) ?? d.playBreakEndSound
        playReminderSound         = try c.decodeIfPresent(Bool.self, forKey: .playReminderSound) ?? d.playReminderSound

        menuBarDisplay            = try c.decodeIfPresent(MenuBarDisplay.self, forKey: .menuBarDisplay) ?? d.menuBarDisplay
        menuBarTimerStyle         = try c.decodeIfPresent(MenuBarTimerStyle.self, forKey: .menuBarTimerStyle) ?? d.menuBarTimerStyle

        screenScoreEnabled        = try c.decodeIfPresent(Bool.self, forKey: .screenScoreEnabled) ?? d.screenScoreEnabled
        screenScoreDisplay        = try c.decodeIfPresent(MenuBarDisplay.self, forKey: .screenScoreDisplay) ?? d.screenScoreDisplay
        screenScoreColoredRings   = try c.decodeIfPresent(Bool.self, forKey: .screenScoreColoredRings) ?? d.screenScoreColoredRings

        trackedBrowsers           = try c.decodeIfPresent(Set<BrowserKind>.self, forKey: .trackedBrowsers) ?? d.trackedBrowsers
    }
}

// MARK: - Preset option lists (drive the onboarding & settings chips)

enum WellnessPresets {
    /// Minutes between breaks.
    static let breakIntervals: [Int] = [10, 20, 30, 45]
    /// Break length in seconds (60 == "1 min").
    static let breakLengths: [Int] = [15, 30, 45, 60]
    /// Reminder cadences in minutes; 0 == "Disabled".
    static let reminderIntervals: [Int] = [0, 10, 20, 30]
    /// Smart-pause cooldown options, in seconds.
    static let cooldowns: [Int] = [0, 30, 60, 120, 300]
    /// Idle thresholds, in seconds.
    static let idleThresholds: [Int] = [30, 60, 120, 300]

    static func intervalLabel(minutes: Int) -> String {
        minutes == 1 ? "1 min" : "\(minutes) mins"
    }

    static func reminderLabel(minutes: Int) -> String {
        minutes == 0 ? "Disabled" : "Every \(minutes) mins"
    }

    static func secondsLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "Off" }
        if seconds >= 60 {
            let m = seconds / 60
            return m == 1 ? "1 minute" : "\(m) minutes"
        }
        return "\(seconds) seconds"
    }
}
