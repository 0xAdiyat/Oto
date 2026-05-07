import SwiftUI

@main
struct OtoApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(openMain: { openWindow(id: "main") })
                .environmentObject(state)
                .preferredColorScheme(.light)
        } label: {
            Image(systemName: "mic.fill")
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
