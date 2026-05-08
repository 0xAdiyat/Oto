import AppKit
import Combine
import Foundation

@MainActor
final class RuleEngine {
    private weak var monitor: AudioDeviceMonitor?
    private weak var store: RuleStore?
    private var cancellables = Set<AnyCancellable>()

    /// Debounce window: ignore repeat fires for the same rule within this many seconds.
    private let debounceWindow: TimeInterval = 3.0
    private var lastFireTimes: [UUID: Date] = [:]

    /// On system wake, devices may take 1–3s to re-enumerate. Defer eval.
    private let wakeDelay: TimeInterval = 2.0

    /// macOS auto-routes to a newly connected Bluetooth device ~0.5–1 s after
    /// connection. We wait this long so our rule fires *after* macOS finishes,
    /// not before (which would let macOS win the race and override our choice).
    private let bluetoothSettleDelay: TimeInterval = 1.5

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
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(self.wakeDelay))
                    self.handleSystemWake()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Event handlers

    private func handleConnected(_ device: AudioDevice) {
        let matches = matchingRules { trigger in
            switch trigger {
            case .deviceConnects(let uid, _) where uid == device.uid: return true
            case .anyBluetoothConnects where device.kind == .bluetooth || device.kind == .airPods: return true
            default: return false
            }
        }
        guard !matches.isEmpty else { return }

        // Bluetooth devices trigger macOS automatic routing after connection.
        // Delay our rule so it runs after macOS finishes, not before.
        let isBluetooth = device.kind == .bluetooth || device.kind == .airPods
        if isBluetooth {
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(bluetoothSettleDelay))
                self.runBatch(matches)
            }
        } else {
            runBatch(matches)
        }
    }

    private func handleDisconnected(_ device: AudioDevice) {
        let matches = matchingRules { trigger in
            if case .deviceDisconnects(let uid, _) = trigger, uid == device.uid { return true }
            return false
        }
        runBatch(matches)
    }

    private func handleSystemWake() {
        let matches = matchingRules { trigger in
            if case .systemWakes = trigger { return true }
            return false
        }
        runBatch(matches)
    }

    private func matchingRules(_ predicate: (RuleTrigger) -> Bool) -> [Rule] {
        guard let store else { return [] }
        let activeProfileID = store.activeProfileID
        return store.rules.filter { rule in
            guard rule.enabled else { return false }
            // Profile filter: nil profileID = always-on; otherwise match active profile.
            if let rp = rule.profileID, rp != activeProfileID { return false }
            return predicate(rule.trigger)
        }
    }

    /// Apply each matching rule in order, suppressing per-rule duplicates within
    /// the debounce window. Posts a single coalesced notification at the end
    /// describing the final state.
    private func runBatch(_ rules: [Rule]) {
        guard !rules.isEmpty, let store else { return }
        let now = Date()

        var lastSuccessSummary: (trigger: String, device: String)? = nil
        var didFireAny = false

        for rule in rules {
            // EC1: debounce.
            if let last = lastFireTimes[rule.id], now.timeIntervalSince(last) < debounceWindow {
                continue
            }
            lastFireTimes[rule.id] = now
            didFireAny = true

            let outcome = apply(rule.action)
            let displayName = outcome.deviceName ?? rule.action.displayText
            store.recordFire(rule: rule, deviceName: displayName, outcome: outcome.kind)

            if case .applied = outcome.kind, let dn = outcome.deviceName {
                lastSuccessSummary = (rule.trigger.displayText, dn)
            }
        }

        // EC8: one notification per event.
        if didFireAny, let summary = lastSuccessSummary {
            NotificationService.shared.notifyRuleFired(
                triggerSummary: summary.trigger,
                deviceName: summary.device
            )
        }
    }

    // MARK: - Action application

    private struct ApplyResult {
        let kind: RuleFireOutcome
        let deviceName: String?
    }

    private func apply(_ action: RuleAction) -> ApplyResult {
        guard let monitor else { return ApplyResult(kind: .failed, deviceName: nil) }

        switch action {
        case .keepCurrent:
            return ApplyResult(kind: .noOp, deviceName: nil)

        case .setInput(let uid, let cachedName):
            return setInput(uid: uid, cachedName: cachedName, monitor: monitor)

        case .setOutput(let uid, let cachedName):
            return setOutput(uid: uid, cachedName: cachedName, monitor: monitor)

        case .setBoth(let inUID, let inName, let outUID, let outName):
            let inputResult = setInput(uid: inUID, cachedName: inName, monitor: monitor)
            let outputResult = setOutput(uid: outUID, cachedName: outName, monitor: monitor)
            // Prefer the more informative outcome; both succeeded → applied.
            if inputResult.kind == .applied && outputResult.kind == .applied {
                let combined: String = {
                    let i = inputResult.deviceName ?? inName
                    let o = outputResult.deviceName ?? outName
                    return i == o ? i : "\(i) + \(o)"
                }()
                return ApplyResult(kind: .applied, deviceName: combined)
            }
            // Surface the first failure.
            if inputResult.kind != .applied && inputResult.kind != .noOp {
                return inputResult
            }
            return outputResult

        case .setInputVolume(let v):
            guard let target = monitor.defaultInputDevice else {
                return ApplyResult(kind: .targetMissing, deviceName: nil)
            }
            do {
                try AudioDeviceVolume.setInputVolume(target, volume: v)
                return ApplyResult(kind: .applied, deviceName: target.name)
            } catch {
                NSLog("Oto: setInputVolume failed: \(error)")
                return ApplyResult(kind: .failed, deviceName: target.name)
            }

        case .toggleInputMute:
            guard let target = monitor.defaultInputDevice else {
                return ApplyResult(kind: .targetMissing, deviceName: nil)
            }
            do {
                let newState = try AudioDeviceVolume.toggleInputMute(target)
                return ApplyResult(kind: .applied, deviceName: "\(target.name) \(newState ? "muted" : "unmuted")")
            } catch {
                NSLog("Oto: toggleInputMute failed: \(error)")
                return ApplyResult(kind: .failed, deviceName: target.name)
            }
        }
    }

    private func setInput(uid: String, cachedName: String, monitor: AudioDeviceMonitor) -> ApplyResult {
        guard let target = monitor.allDevices.first(where: { $0.uid == uid && $0.hasInput }) else {
            return ApplyResult(kind: .targetMissing, deviceName: cachedName)
        }
        do {
            try AudioDeviceSwitcher.setDefaultInput(target)
            return ApplyResult(kind: .applied, deviceName: target.name.isEmpty ? cachedName : target.name)
        } catch {
            NSLog("Oto: setDefaultInput failed: \(error)")
            return ApplyResult(kind: .failed, deviceName: target.name)
        }
    }

    private func setOutput(uid: String, cachedName: String, monitor: AudioDeviceMonitor) -> ApplyResult {
        guard let target = monitor.allDevices.first(where: { $0.uid == uid && $0.hasOutput }) else {
            return ApplyResult(kind: .targetMissing, deviceName: cachedName)
        }
        do {
            try AudioDeviceSwitcher.setDefaultOutput(target)
            return ApplyResult(kind: .applied, deviceName: target.name.isEmpty ? cachedName : target.name)
        } catch {
            NSLog("Oto: setDefaultOutput failed: \(error)")
            return ApplyResult(kind: .failed, deviceName: target.name)
        }
    }
}
