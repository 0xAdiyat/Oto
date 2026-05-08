import AppKit
import Combine
import Foundation
import Observation

/// Continuously re-asserts user-pinned default input/output devices
/// whenever macOS auto-routes away from them. The user opts a specific
/// device into "lock" — Oto fights every override until they unlock or
/// the device disconnects.
///
/// This lives outside the rule engine because it's a *veto* rather than
/// an event-driven action: the trigger is "macOS changed the default
/// away from my pinned UID", which has no place in the existing trigger
/// taxonomy without leaking implementation detail.
///
/// Race handling: macOS auto-routes ~0.5–1 s after a Bluetooth connect
/// completes. We wait `settleDelay` seconds before re-asserting so our
/// write is the last word, mirroring the same delay the rule engine
/// uses for the "AirPods stole my mic" defense.
@Observable
@MainActor
final class DeviceLockManager {
    /// UID of the locked default input device, or nil if the user hasn't
    /// pinned one. UIDs are stable across reboots; we can't use
    /// `AudioDeviceID` because IDs are session-scoped.
    var lockedInputUID: String? { didSet { save() ; assertOnLockChange(direction: .input, oldUID: oldValue) } }
    var lockedOutputUID: String? { didSet { save() ; assertOnLockChange(direction: .output, oldUID: oldValue) } }

    @ObservationIgnored private weak var monitor: AudioDeviceMonitor?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    /// Coalesces back-to-back default-changed events so a flurry of macOS
    /// routing decisions only triggers one re-assertion attempt.
    @ObservationIgnored private var pendingInputAssertion: Task<Void, Never>?
    @ObservationIgnored private var pendingOutputAssertion: Task<Void, Never>?

    /// Tracks whether *we* are the source of the most recent default
    /// change. When we set the default, the listener fires again — without
    /// this flag we'd register that as "macOS changed away" and re-assert
    /// in a tight loop.
    @ObservationIgnored private var suppressInputUntil: Date?
    @ObservationIgnored private var suppressOutputUntil: Date?

    private let settleDelay: TimeInterval = 1.5
    private let suppressionWindow: TimeInterval = 0.5

    private static let inputKey = "Oto.deviceLock.input.v1"
    private static let outputKey = "Oto.deviceLock.output.v1"

    init() {
        lockedInputUID  = UserDefaults.standard.string(forKey: Self.inputKey)
        lockedOutputUID = UserDefaults.standard.string(forKey: Self.outputKey)
    }

    // MARK: - Public API

    func start(monitor: AudioDeviceMonitor) {
        self.monitor = monitor

        monitor.defaultInputChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleAssertion(direction: .input) }
            .store(in: &cancellables)

        monitor.defaultOutputChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleAssertion(direction: .output) }
            .store(in: &cancellables)

        // When the locked device reappears after a disconnect, immediately
        // re-pin it as default.
        monitor.deviceConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in
                guard let self else { return }
                if device.uid == self.lockedInputUID  { self.scheduleAssertion(direction: .input) }
                if device.uid == self.lockedOutputUID { self.scheduleAssertion(direction: .output) }
            }
            .store(in: &cancellables)

        // Initial pass — if Oto launches and the default doesn't already
        // match the locked UID, fix it.
        scheduleAssertion(direction: .input)
        scheduleAssertion(direction: .output)
    }

    /// Sugar for the toggle UI in DevicesSheet. Locking a new device for
    /// a direction implicitly unlocks the previous one — only one device
    /// can be locked per direction.
    func toggleLock(_ device: AudioDevice, direction: Direction) {
        switch direction {
        case .input:
            lockedInputUID = (lockedInputUID == device.uid) ? nil : device.uid
        case .output:
            lockedOutputUID = (lockedOutputUID == device.uid) ? nil : device.uid
        }
    }

    func isLocked(_ device: AudioDevice, direction: Direction) -> Bool {
        switch direction {
        case .input:  return lockedInputUID == device.uid
        case .output: return lockedOutputUID == device.uid
        }
    }

    // MARK: - Internals

    enum Direction { case input, output }

    private func save() {
        if let v = lockedInputUID  { UserDefaults.standard.set(v, forKey: Self.inputKey)  } else { UserDefaults.standard.removeObject(forKey: Self.inputKey) }
        if let v = lockedOutputUID { UserDefaults.standard.set(v, forKey: Self.outputKey) } else { UserDefaults.standard.removeObject(forKey: Self.outputKey) }
    }

    /// Lock targets changed at runtime — kick an immediate enforcement
    /// pass so the user sees the lock take effect right away rather than
    /// waiting for the next system event.
    private func assertOnLockChange(direction: Direction, oldUID: String?) {
        // Only schedule if the lock is *now* set; clearing a lock is a
        // no-op (we don't want to "undo" a previous assertion).
        switch direction {
        case .input  where lockedInputUID  != nil: scheduleAssertion(direction: .input)
        case .output where lockedOutputUID != nil: scheduleAssertion(direction: .output)
        default: break
        }
        _ = oldUID
    }

    private func scheduleAssertion(direction: Direction) {
        // Cancel any pending re-assertion for this direction so multiple
        // rapid-fire default-changed events collapse to a single attempt.
        switch direction {
        case .input:  pendingInputAssertion?.cancel()
        case .output: pendingOutputAssertion?.cancel()
        }

        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.settleDelay ?? 1.5))
            guard !Task.isCancelled else { return }
            self?.enforce(direction: direction)
        }

        switch direction {
        case .input:  pendingInputAssertion  = task
        case .output: pendingOutputAssertion = task
        }
    }

    private func enforce(direction: Direction) {
        guard let monitor else { return }

        let now = Date()
        // Bail if we ourselves just wrote — listener will fire again with
        // the value we just set, and we don't want to re-assert in a loop.
        switch direction {
        case .input:
            if let until = suppressInputUntil, now < until { return }
        case .output:
            if let until = suppressOutputUntil, now < until { return }
        }

        let lockedUID: String?
        let currentUID: String?
        switch direction {
        case .input:
            lockedUID  = lockedInputUID
            currentUID = monitor.defaultInputDevice?.uid
        case .output:
            lockedUID  = lockedOutputUID
            currentUID = monitor.defaultOutputDevice?.uid
        }

        guard let lockedUID else { return }
        guard currentUID != lockedUID else { return }

        // Locked device must be currently connected and have the right
        // direction. If it's missing, we wait — `deviceConnected` will
        // call us again when it reappears.
        let predicate: (AudioDevice) -> Bool = { device in
            switch direction {
            case .input:  return device.uid == lockedUID && device.hasInput
            case .output: return device.uid == lockedUID && device.hasOutput
            }
        }
        guard let target = monitor.allDevices.first(where: predicate) else { return }

        do {
            switch direction {
            case .input:
                suppressInputUntil = now.addingTimeInterval(suppressionWindow)
                try AudioDeviceSwitcher.setDefaultInput(target)
            case .output:
                suppressOutputUntil = now.addingTimeInterval(suppressionWindow)
                try AudioDeviceSwitcher.setDefaultOutput(target)
            }
        } catch {
            NSLog("Oto: device lock re-assertion failed for \(direction): \(error)")
        }
    }
}
