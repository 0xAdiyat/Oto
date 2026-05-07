import AppKit
import Combine
import Foundation

@MainActor
final class RuleEngine {
    private weak var monitor: AudioDeviceMonitor?
    private weak var store: RuleStore?
    private var cancellables = Set<AnyCancellable>()

    init(monitor: AudioDeviceMonitor, store: RuleStore) {
        self.monitor = monitor
        self.store = store

        monitor.deviceConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in self?.handleConnected(device) }
            .store(in: &cancellables)

        monitor.deviceDisconnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in self?.handleDisconnected(device) }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleSystemWake() }
            .store(in: &cancellables)
    }

    private func handleConnected(_ device: AudioDevice) {
        guard let store else { return }
        for rule in store.rules where rule.enabled {
            switch rule.trigger {
            case .deviceConnects(let uid, _) where uid == device.uid:
                fire(rule)
            case .anyBluetoothConnects where device.kind == .bluetooth || device.kind == .airPods:
                fire(rule)
            default:
                break
            }
        }
    }

    private func handleDisconnected(_ device: AudioDevice) {
        guard let store else { return }
        for rule in store.rules where rule.enabled {
            if case .deviceDisconnects(let uid, _) = rule.trigger, uid == device.uid {
                fire(rule)
            }
        }
    }

    private func handleSystemWake() {
        guard let store else { return }
        for rule in store.rules where rule.enabled {
            if case .systemWakes = rule.trigger {
                fire(rule)
            }
        }
    }

    private func fire(_ rule: Rule) {
        guard let store else { return }
        let chosenName = apply(rule.action)
        store.recordFire(rule: rule, deviceName: chosenName ?? rule.action.displayText)
        if chosenName != nil {
            NotificationService.shared.notifyRuleFired(
                triggerSummary: rule.trigger.displayText,
                deviceName: chosenName ?? ""
            )
        }
    }

    /// Returns the display name of the device that was selected, or nil if the action was a no-op.
    private func apply(_ action: RuleAction) -> String? {
        guard let monitor else { return nil }
        switch action {
        case .keepCurrent:
            return nil
        case .setInput(let uid, let name):
            guard let target = monitor.allDevices.first(where: { $0.uid == uid && $0.hasInput }) else {
                return nil
            }
            do {
                try AudioDeviceSwitcher.setDefaultInput(target)
                return target.name.isEmpty ? name : target.name
            } catch {
                NSLog("Oto: failed to switch input: \(error)")
                return nil
            }
        }
    }
}
