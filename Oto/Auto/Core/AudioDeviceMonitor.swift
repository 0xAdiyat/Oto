import CoreAudio
import Foundation
import Combine
import Observation

/// Observes the system audio device list and default input device via CoreAudio
/// property listeners, publishing changes through stored properties and
/// PassthroughSubjects for connect/disconnect events.
@Observable
@MainActor
final class AudioDeviceMonitor {

    var allDevices: [AudioDevice] = []
    var defaultInputDevice: AudioDevice?

    @ObservationIgnored let deviceConnected = PassthroughSubject<AudioDevice, Never>()
    @ObservationIgnored let deviceDisconnected = PassthroughSubject<AudioDevice, Never>()

    @ObservationIgnored nonisolated(unsafe) private var devicesListenerInstalled = false
    @ObservationIgnored nonisolated(unsafe) private var defaultInputListenerInstalled = false

    init() {
        allDevices = Self.fetchAllDevices()
        defaultInputDevice = Self.fetchDefaultInputDevice()
        installListeners()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Fetching

    private nonisolated static func fetchAllDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { AudioDevice.from(deviceID: $0) }
    }

    private nonisolated static func fetchDefaultInputDevice() -> AudioDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return AudioDevice.from(deviceID: deviceID)
    }

    // MARK: - Property Listeners

    private func installListeners() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            onDevicesChanged,
            selfPtr
        ) == noErr {
            devicesListenerInstalled = true
        }

        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &inputAddress,
            onDefaultInputChanged,
            selfPtr
        ) == noErr {
            defaultInputListenerInstalled = true
        }
    }

    private nonisolated func removeListeners() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        if devicesListenerInstalled {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject), &address, onDevicesChanged, selfPtr
            )
        }

        if defaultInputListenerInstalled {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject), &address, onDefaultInputChanged, selfPtr
            )
        }
    }

    // MARK: - Callback Handlers (called from CoreAudio thread)

    fileprivate nonisolated func handleDevicesChanged() {
        let newDevices = Self.fetchAllDevices()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let oldUIDs = Set(self.allDevices.map(\.uid))
            let newUIDs = Set(newDevices.map(\.uid))

            let connected = newDevices.filter { !oldUIDs.contains($0.uid) }
            let disconnected = self.allDevices.filter { !newUIDs.contains($0.uid) }

            self.allDevices = newDevices
            self.defaultInputDevice = Self.fetchDefaultInputDevice()

            for device in connected { self.deviceConnected.send(device) }
            for device in disconnected { self.deviceDisconnected.send(device) }
        }
    }

    fileprivate nonisolated func handleDefaultInputChanged() {
        let newDefault = Self.fetchDefaultInputDevice()

        DispatchQueue.main.async { [weak self] in
            self?.defaultInputDevice = newDefault
        }
    }
}

// MARK: - C-function listener callbacks

private nonisolated func onDevicesChanged(
    _ objectID: AudioObjectID,
    _ count: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<AudioDeviceMonitor>.fromOpaque(clientData).takeUnretainedValue().handleDevicesChanged()
    return noErr
}

private nonisolated func onDefaultInputChanged(
    _ objectID: AudioObjectID,
    _ count: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<AudioDeviceMonitor>.fromOpaque(clientData).takeUnretainedValue().handleDefaultInputChanged()
    return noErr
}
