import AppKit
import Combine
import Foundation
import Observation

/// Observes macOS app launch events via NSWorkspace and publishes a
/// `LaunchedApp` whenever a new app transitions into the running state.
///
/// Why a passthrough subject instead of @Observable state: rules fire on
/// the *event* of launch, not on the resulting "is X running?" flag. A
/// PassthroughSubject mirrors how `AudioDeviceMonitor` exposes connect /
/// disconnect events to the rule engine.
@Observable
@MainActor
final class AppLaunchMonitor {

    /// All apps currently running. Updated on every launch/terminate
    /// notification. Powers the rule editor's "pick from running apps"
    /// dropdown.
    var runningApps: [LaunchedApp] = []

    @ObservationIgnored let appLaunched = PassthroughSubject<LaunchedApp, Never>()

    @ObservationIgnored private var launchObserver: NSObjectProtocol?
    @ObservationIgnored private var terminateObserver: NSObjectProtocol?

    init() {
        runningApps = Self.snapshotRunningApps()
        let center = NSWorkspace.shared.notificationCenter

        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            // Background-only / agent apps fire didLaunchApplication too,
            // which is fine — but skip our own bundle to avoid recursion if
            // we're ever re-launched by the helper.
            if bundleID == Bundle.main.bundleIdentifier { return }

            let entry = LaunchedApp(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID
            )

            // Update the running set first so any synchronous subscriber
            // that consults `runningApps` sees the freshly-launched app.
            Task { @MainActor in
                self.runningApps = Self.snapshotRunningApps()
                self.appLaunched.send(entry)
            }
        }

        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.runningApps = Self.snapshotRunningApps()
            }
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let o = launchObserver { center.removeObserver(o) }
        if let o = terminateObserver { center.removeObserver(o) }
    }

    /// True when an app with the given bundle ID is currently running.
    /// Used by guardrails (e.g. quiet hours, future locks) to interrogate
    /// state — events alone aren't enough because the app may have launched
    /// before Oto did.
    func isRunning(bundleID: String) -> Bool {
        runningApps.contains { $0.bundleID == bundleID }
    }

    private static func snapshotRunningApps() -> [LaunchedApp] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleID = app.bundleIdentifier,
                  bundleID != Bundle.main.bundleIdentifier else { return nil }
            return LaunchedApp(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID
            )
        }
        // Sort by display name for the picker UX.
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Tiny value-type description of a running app — just enough to identify
/// it for rule storage and display.
struct LaunchedApp: Identifiable, Hashable {
    let bundleID: String
    let name: String

    var id: String { bundleID }
}

// MARK: - Well-known apps

/// Curated list of common audio-routing-relevant apps. Shown at the top of
/// the picker even when the app isn't running — so a user can wire up "When
/// Spotify launches" before they've ever opened Spotify in this session.
enum WellKnownApps {
    static let suggestions: [LaunchedApp] = [
        LaunchedApp(bundleID: "com.spotify.client",          name: "Spotify"),
        LaunchedApp(bundleID: "com.apple.Music",             name: "Music"),
        LaunchedApp(bundleID: "us.zoom.xos",                 name: "Zoom"),
        LaunchedApp(bundleID: "com.microsoft.teams2",        name: "Microsoft Teams"),
        LaunchedApp(bundleID: "com.tinyspeck.slackmacgap",   name: "Slack"),
        LaunchedApp(bundleID: "com.hnc.Discord",             name: "Discord"),
        LaunchedApp(bundleID: "com.apple.FaceTime",          name: "FaceTime"),
        LaunchedApp(bundleID: "com.apple.QuickTimePlayerX",  name: "QuickTime Player"),
        LaunchedApp(bundleID: "com.apple.logic10",           name: "Logic Pro"),
        LaunchedApp(bundleID: "com.apple.garageband10",      name: "GarageBand"),
    ]
}
