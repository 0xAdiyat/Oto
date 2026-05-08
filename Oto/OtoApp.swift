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
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
        .menuBarExtraStyle(.window)
    }
}
