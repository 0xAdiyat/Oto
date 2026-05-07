import SwiftUI

// Legacy placeholder. The active root views are MenuBarView and MainWindowView in OtoApp.swift.
struct ContentView: View {
    var body: some View {
        MainWindowView()
    }
}

#Preview("Main Window") {
    MainWindowView()
        .environmentObject(AppState())
        .frame(width: 980, height: 640)
}

#Preview("Menu Bar") {
    MenuBarView(openMain: {})
        .environmentObject(AppState())
}
