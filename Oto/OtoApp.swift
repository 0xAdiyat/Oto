import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let me = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: me.bundleIdentifier ?? ""
        ).filter { $0 != me }
        for app in others {
            app.terminate()
        }
    }
}

@main
struct OtoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(openMain: { openWindow(id: "main") })
                .environmentObject(state)
                .preferredColorScheme(.light)
        } label: {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 18)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Oto", id: "main") {
            MainWindowView()
                .environmentObject(state)
                .frame(minWidth: 880, minHeight: 600)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentSize)
    }
}
