import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

/// Wraps the Sparkle auto-updater for the General → Updates section.
///
/// Sparkle is linked via Swift Package Manager (`https://github.com/sparkle-project/Sparkle`).
/// The whole type is guarded by `#if canImport(Sparkle)` so the app still builds
/// and the Updates UI still renders before the package is added — the toggles
/// then persist to the same `UserDefaults` keys Sparkle uses (`SUEnableAutomaticChecks`,
/// `SUAutomaticallyUpdate`), so they take effect the moment the package is linked.
///
/// Real update delivery additionally needs `SUFeedURL` + `SUPublicEDKey` in
/// Info.plist and a hosted `appcast.xml` (see the spec's deploy follow-ups).
@MainActor
final class UpdateController {
    static let shared = UpdateController()

    #if canImport(Sparkle)
    private let controller: SPUStandardUpdaterController
    #endif

    private init() {
        #if canImport(Sparkle)
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    /// Whether the Sparkle framework is linked into this build.
    var isAvailable: Bool {
        #if canImport(Sparkle)
        return true
        #else
        return false
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return controller.updater.automaticallyChecksForUpdates
            #else
            return UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks")
            #endif
        }
        set {
            #if canImport(Sparkle)
            controller.updater.automaticallyChecksForUpdates = newValue
            #else
            UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks")
            #endif
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return controller.updater.automaticallyDownloadsUpdates
            #else
            return UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate")
            #endif
        }
        set {
            #if canImport(Sparkle)
            controller.updater.automaticallyDownloadsUpdates = newValue
            #else
            UserDefaults.standard.set(newValue, forKey: "SUAutomaticallyUpdate")
            #endif
        }
    }

    /// Trigger a user-initiated update check (shows Sparkle's standard UI).
    func checkForUpdates() {
        #if canImport(Sparkle)
        controller.checkForUpdates(nil)
        #endif
    }
}
