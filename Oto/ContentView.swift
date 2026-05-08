import SwiftUI

// Previews for the active root views (MenuBarView and MainWindowView in OtoApp.swift).

#Preview("Main Window") {
    MainWindowView()
        .environment(AppState())
        .frame(width: 980, height: 640)
}

#Preview("Menu Bar") {
    MenuBarView(openMain: {})
        .environment(AppState())
}
