import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let firstRunSetupCompletedKey = "Oto.hasCompletedFirstRunSetup.v1"

    let monitor: AudioDeviceMonitor
    let store: RuleStore
    let appLaunchMonitor: AppLaunchMonitor
    let quietHours: QuietHoursManager
    let deviceLock: DeviceLockManager
    private let engine: RuleEngine
    var isShowingFirstRunSetup = false

    init() {
        let monitor = AudioDeviceMonitor()
        let store = RuleStore()
        let appLaunchMonitor = AppLaunchMonitor()
        let quietHours = QuietHoursManager()
        let deviceLock = DeviceLockManager()

        self.monitor = monitor
        self.store = store
        self.appLaunchMonitor = appLaunchMonitor
        self.quietHours = quietHours
        self.deviceLock = deviceLock
        self.engine = RuleEngine(monitor: monitor, store: store, appMonitor: appLaunchMonitor)

        // Start the guardrails after the engine is constructed so the
        // re-assertion logic sees a fully-wired audio pipeline.
        quietHours.start(monitor: monitor)
        deviceLock.start(monitor: monitor)
    }

    var inputDevices: [AudioDevice] {
        monitor.allDevices.filter(\.hasInput)
    }

    func switchTo(_ device: AudioDevice) {
        try? AudioDeviceSwitcher.setDefaultInput(device)
    }

    func presentFirstRunSetup() {
        isShowingFirstRunSetup = true
    }

    func completeFirstRunSetup() {
        UserDefaults.standard.set(true, forKey: Self.firstRunSetupCompletedKey)
        isShowingFirstRunSetup = false
    }
}
