import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    let monitor: AudioDeviceMonitor
    let store: RuleStore
    private let engine: RuleEngine

    init() {
        let monitor = AudioDeviceMonitor()
        let store = RuleStore()
        self.monitor = monitor
        self.store = store
        self.engine = RuleEngine(monitor: monitor, store: store)
    }

    var inputDevices: [AudioDevice] {
        monitor.allDevices.filter(\.hasInput)
    }

    func switchTo(_ device: AudioDevice) {
        try? AudioDeviceSwitcher.setDefaultInput(device)
    }
}
