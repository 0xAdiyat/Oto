import Foundation
import ServiceManagement

/// Wraps SMAppService.mainApp for the simple "launch this app at login" toggle.
/// Available on macOS 13+.
@MainActor
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Oto: failed to toggle launch at login: \(error)")
        }
    }
}
