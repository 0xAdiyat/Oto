import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let me = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: me.bundleIdentifier ?? ""
        ).filter { $0 != me }
        for app in others {
            app.terminate()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — Oto lives in the menu bar.
        NSApp.setActivationPolicy(.accessory)
        SpotlightWindowController.shared.install(
            rootView: MainWindowView().environment(state)
        )

        // Wire the optional global hotkey: when fired, toggle the spotlight
        // panel. The manager singleton self-restores any persisted shortcut
        // on init, so by this point registration has already been attempted.
        GlobalHotkeyManager.shared.onFire = {
            SpotlightWindowController.shared.toggle()
        }

        // First-run: present the wellbeing onboarding (the primary setup flow).
        // The audio first-run wizard remains reachable from Settings.
        if !state.hasCompletedOnboarding {
            state.presentOnboarding()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SpotlightWindowController.shared.present(activate: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct OtoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(openMain: {
                SpotlightWindowController.shared.present(activate: true)
            })
            .environment(appDelegate.state)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.state)
        }
        .menuBarExtraStyle(.window)

        // Standard macOS Preferences window. Discoverable through the App
        // menu (⌘,) and via `openSettings` from anywhere in the UI. Lives
        // alongside MenuBarExtra without forcing a Dock icon.
        Settings {
            OtoSettingsView()
                .environment(appDelegate.state)
        }
    }
}
