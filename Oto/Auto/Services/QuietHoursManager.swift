import AppKit
import Combine
import CoreAudio
import Foundation
import Observation

/// Codable persistence + display model for the quiet-hours guardrail.
/// Stored separately from rules because it's a continuous monitor, not
/// an event-driven action.
struct QuietHoursSettings: Codable, Hashable {
    var enabled: Bool
    /// Minutes since midnight (0...1439). Window may wrap midnight when
    /// `endMinute < startMinute` (e.g. 22:00 → 06:00).
    var startMinute: Int
    var endMinute: Int
    /// Maximum allowed output volume during the window, 0...1. The manager
    /// clamps any volume above this, with a tiny epsilon to avoid runaway
    /// loops triggered by float drift in CoreAudio's volume scalar.
    var maxVolume: Double

    static let `default` = QuietHoursSettings(
        enabled: false,
        startMinute: 1 * 60,    // 01:00
        endMinute:   7 * 60,    // 07:00
        maxVolume:   0.7
    )

    /// True when `now` (HH:MM only) falls within the configured window,
    /// with correct wrap-around handling. Edge inclusive on the start
    /// boundary, exclusive on the end — matches how Apple's Focus Mode
    /// schedule reads.
    func isInWindow(now: Date = .now, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        // Equal start/end is treated as "all day" — the user's only way
        // to say "never enforce" is the enabled toggle, not a zero-width
        // window. We reject equal values in the UI but defend here too.
        if startMinute == endMinute { return enabled }
        if startMinute < endMinute {
            // Same-day window, e.g. 13:00 → 17:00.
            return nowMinute >= startMinute && nowMinute < endMinute
        }
        // Wrap-around window, e.g. 22:00 → 06:00.
        return nowMinute >= startMinute || nowMinute < endMinute
    }
}

/// Continuously enforces a max output volume during a configurable
/// time window. Reacts to volume changes via a CoreAudio property listener
/// AND polls every 30 s so window-entry edges trigger a clamp even when
/// the user hasn't touched the volume since.
///
/// Loop-avoidance: when we set the volume to the cap, the listener fires
/// again, but `current > maxVolume + epsilon` is now false, so we no-op.
@Observable
@MainActor
final class QuietHoursManager {
    var settings: QuietHoursSettings = .default {
        didSet { onSettingsChanged(old: oldValue) }
    }

    @ObservationIgnored private weak var monitor: AudioDeviceMonitor?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    /// Currently-listened device + the property listener function. Stored
    /// so we can detach when the default output changes (the listener is
    /// per-device, not system-wide — a freshly-connected output gets its
    /// own listener install).
    @ObservationIgnored nonisolated(unsafe) private var listenedDeviceID: AudioDeviceID?
    @ObservationIgnored nonisolated(unsafe) private var listenedAddresses: [AudioObjectPropertyAddress] = []

    /// A short follow-up clamp after a volume-change callback. Some macOS
    /// volume key paths emit the property notification before the final scalar
    /// has settled; rechecking a fraction later makes the cap feel locked.
    @ObservationIgnored private var pendingReassertion: Task<Void, Never>?

    /// Five-second tick — cheap, but frequent enough to recover quickly on
    /// devices that do not emit software volume property notifications.
    @ObservationIgnored private var tickTimer: Timer?

    /// Avoid spamming the user with banner notifications when CoreAudio
    /// emits multiple volume-change events in a row. Track the last notify
    /// time and rate-limit, but keep it short enough that a repeated manual
    /// attempt still gets clear feedback.
    @ObservationIgnored private var lastNotificationAt: Date?
    @ObservationIgnored private static let notificationCooldown: TimeInterval = 12

    private static let storageKey = "Oto.quietHours.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(QuietHoursSettings.self, from: data) {
            settings = decoded
        }
    }

    deinit {
        tickTimer?.invalidate()
        pendingReassertion?.cancel()
        if let id = listenedDeviceID, !listenedAddresses.isEmpty {
            removeListener(deviceID: id)
        }
    }

    func start(monitor: AudioDeviceMonitor) {
        self.monitor = monitor

        // Re-attach the listener whenever the default output device flips —
        // otherwise a Bluetooth disconnect would orphan the listener on a
        // device that no longer exists.
        monitor.defaultOutputChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshListener()
                self?.enforceIfNeeded()
            }
            .store(in: &cancellables)

        refreshListener()

        // Periodic tick — drives window-entry enforcement and backs up
        // devices that don't notify on volume key changes.
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.enforceIfNeeded()
            }
            _ = self // silence unused-warning when Task body is the only ref
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer

        // Initial pass — if the user launches Oto at 02:00 with volume at
        // 100% and quiet hours enabled, clamp immediately.
        enforceIfNeeded()
    }

    // MARK: - Settings change

    private func onSettingsChanged(old: QuietHoursSettings) {
        save()
        // If we just turned on, do an immediate enforcement pass.
        if !old.enabled && settings.enabled {
            enforceIfNeeded()
        }
        // If the cap changed and we're already in-window, re-enforce so
        // the user sees the new ceiling take effect right away.
        if old.maxVolume != settings.maxVolume {
            enforceIfNeeded()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Listener management

    private func refreshListener() {
        // Tear down the previous listener if any.
        if let oldID = listenedDeviceID, !listenedAddresses.isEmpty {
            removeListener(deviceID: oldID)
        }
        listenedDeviceID = nil
        listenedAddresses = []

        guard let dev = monitor?.defaultOutputDevice else { return }
        installListener(deviceID: dev.deviceID)
        listenedDeviceID = dev.deviceID
    }

    private func installListener(deviceID: AudioDeviceID) {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for element in Self.volumeElements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let status = AudioObjectAddPropertyListener(
                deviceID,
                &address,
                quietHoursVolumeListener,
                selfPtr
            )
            if status == noErr {
                listenedAddresses.append(address)
            }
        }
    }

    private nonisolated func removeListener(deviceID: AudioDeviceID) {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for storedAddress in listenedAddresses {
            var address = storedAddress
            AudioObjectRemovePropertyListener(
                deviceID, &address, quietHoursVolumeListener, selfPtr
            )
        }
        listenedAddresses = []
    }

    fileprivate nonisolated func handleVolumeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.enforceIfNeeded()
            self?.scheduleReassertion()
        }
    }

    // MARK: - Enforcement

    /// The single decision point — called from the listener, the periodic
    /// tick, the settings-changed hook, and the default-output-changed
    /// publisher. Idempotent and cheap.
    private func enforceIfNeeded() {
        guard settings.enabled,
              settings.isInWindow(),
              let dev = monitor?.defaultOutputDevice,
              let current = AudioDeviceVolume.getOutputVolume(dev) else { return }

        // Epsilon guards against float drift and the listener echo from
        // our own write. 0.005 = roughly half a percent.
        let epsilon = 0.005
        guard current > settings.maxVolume + epsilon else { return }

        do {
            try AudioDeviceVolume.setOutputVolume(dev, volume: settings.maxVolume)
            maybeNotify(currentPercent: Int(current * 100))
        } catch {
            NSLog("Oto: quiet hours setOutputVolume failed: \(error)")
        }
    }

    private func scheduleReassertion() {
        pendingReassertion?.cancel()
        pendingReassertion = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.enforceIfNeeded()
        }
    }

    private func maybeNotify(currentPercent: Int) {
        let now = Date()
        if let last = lastNotificationAt,
           now.timeIntervalSince(last) < Self.notificationCooldown {
            return
        }
        lastNotificationAt = now
        NotificationService.shared.notifyQuietHoursClamped(
            cappedPercent: Int(settings.maxVolume * 100),
            attemptedPercent: currentPercent
        )
    }

    private static let volumeElements: [UInt32] = [
        kAudioObjectPropertyElementMain,
        1,
        2
    ]
}

// MARK: - C listener

/// Marked `nonisolated` so the C function pointer cast doesn't lose the
/// MainActor annotation (which Swift 6 will reject). The handler hops back
/// to the main actor inside `handleVolumeChanged` via DispatchQueue.
private nonisolated func quietHoursVolumeListener(
    _ objectID: AudioObjectID,
    _ count: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<QuietHoursManager>.fromOpaque(clientData).takeUnretainedValue().handleVolumeChanged()
    return noErr
}
