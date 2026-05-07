import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let monitor: AudioDeviceMonitor
    let store: RuleStore
    private let engine: RuleEngine
    private var cancellables = Set<AnyCancellable>()

    init() {
        let monitor = AudioDeviceMonitor()
        let store = RuleStore()
        self.monitor = monitor
        self.store = store
        self.engine = RuleEngine(monitor: monitor, store: store)

        monitor.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        store.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var inputDevices: [AudioDevice] {
        monitor.allDevices.filter(\.hasInput)
    }

    func switchTo(_ device: AudioDevice) {
        try? AudioDeviceSwitcher.setDefaultInput(device)
    }
}
