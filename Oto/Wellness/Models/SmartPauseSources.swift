import Foundation

/// Which activities automatically pause the focus timer (LookAway "Smart Pause").
/// Reliable signals (deep-focus apps, calendar) are fully wired in
/// `SmartPauseSourceDetector`; meetings / video / gaming / screen-recording are
/// best-effort heuristics. Each is individually toggleable. Persisted inside
/// `WellnessSettings`.
struct SmartPauseSources: Codable, Hashable {
    var meetingsCalls: Bool
    var videoPlayback: Bool
    var calendarEvents: Bool
    var deepFocusApps: Bool
    var gaming: Bool
    var screenRecording: Bool

    /// Bundle IDs that trigger the deep-focus pause when frontmost.
    var deepFocusBundleIDs: [String]
    /// Bundle IDs treated as games for the gaming pause.
    var gamingBundleIDs: [String]

    static let `default` = SmartPauseSources(
        meetingsCalls: false,
        videoPlayback: false,
        calendarEvents: false,
        deepFocusApps: false,
        gaming: false,
        screenRecording: false,
        deepFocusBundleIDs: [],
        gamingBundleIDs: []
    )

    /// True if any source that needs per-poll detection is on (lets the
    /// detector skip work entirely when nothing is enabled).
    var anyEnabled: Bool {
        meetingsCalls || videoPlayback || calendarEvents
            || deepFocusApps || gaming || screenRecording
    }
}
