import AppKit
import CoreGraphics
import EventKit
import IOKit
import IOKit.pwr_mgt

/// Detects the activity-based Smart Pause sources (LookAway's "Automatically
/// pause during …"). Polled by `SmartPauseMonitor` on its 5-second cadence.
///
/// **Reliable** signals are fully wired: deep-focus apps (frontmost bundle ID),
/// calendar events (EventKit), and active typing/dragging (`CGEventSource`).
/// **Best-effort** signals use coarse heuristics: meetings/screen-recording via
/// known running apps, video via display-sleep assertions, gaming via frontmost
/// bundle ID. Never crashes on a system-API failure — it degrades to "not
/// paused" per the error-handling standard.
@MainActor
final class SmartPauseSourceDetector {
    private let store: WellnessStore
    private let eventStore = EKEventStore()

    init(store: WellnessStore) {
        self.store = store
    }

    /// Known conferencing apps (best-effort meetings/calls detection).
    private static let meetingApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp", "com.webex.meetingmanager",
        "com.google.Chrome.app.meet", "com.hnc.Discord", "com.tinyspeck.slackmacgap",
    ]
    /// Known screen-recording / capture apps (best-effort).
    private static let recorderApps: Set<String> = [
        "com.obsproject.obs-studio", "com.telestream.screenflow11",
        "com.telestream.screenflow10", "com.apple.QuickTimePlayerX",
        "com.techsmith.snagit2024", "com.linebreak.CloudApp",
    ]

    private var frontmostBundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func anyRunning(_ ids: Set<String>) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            guard let id = $0.bundleIdentifier else { return false }
            return ids.contains(id)
        }
    }

    /// True while any app holds a "prevent user idle display sleep" assertion —
    /// what video players (and full-screen video on the web) take while playing.
    private func videoAssertionActive() -> Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Any] else { return false }
        let count = (dict["PreventUserIdleDisplaySleep"] as? Int) ?? 0
        return count > 0
    }

    private var calendarAuthorized: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return s == .fullAccess }
        return s == .authorized
    }

    private func calendarBusy() -> Bool {
        guard calendarAuthorized else { return false }
        let now = Date()
        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(60),
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)
        return events.contains {
            !$0.isAllDay && $0.availability != .free
                && $0.startDate <= now && $0.endDate >= now
        }
    }

    // MARK: Public API

    /// Whether any *enabled* source currently warrants pausing the focus timer.
    func isPausedBySource() -> Bool {
        let src = store.settings.smartPauseSources
        guard src.anyEnabled else { return false }

        if src.deepFocusApps, let f = frontmostBundleID, src.deepFocusBundleIDs.contains(f) { return true }
        if src.gaming, let f = frontmostBundleID, src.gamingBundleIDs.contains(f) { return true }
        if src.meetingsCalls, anyRunning(Self.meetingApps) { return true }
        if src.screenRecording, anyRunning(Self.recorderApps) { return true }
        if src.videoPlayback, videoAssertionActive() { return true }
        if src.calendarEvents, calendarBusy() { return true }
        return false
    }

    /// True while the user is actively typing or dragging (used for the
    /// "don't show breaks while typing/dragging/dictating" gate).
    func isInputBusy() -> Bool {
        let key = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let drag = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDragged)
        return min(key, drag) < 2.0
    }

    // MARK: Calendar permission

    /// Whether Oto already has calendar read access.
    static var hasCalendarAccess: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return s == .fullAccess }
        return s == .authorized
    }

    /// Request calendar access for the "Grant permissions…" button. Safe to call
    /// repeatedly; completion runs on the main actor with the granted flag.
    static func requestCalendarAccess(_ completion: @escaping @MainActor (Bool) -> Void) {
        let store = EKEventStore()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                Task { @MainActor in completion(granted) }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                Task { @MainActor in completion(granted) }
            }
        }
    }
}
