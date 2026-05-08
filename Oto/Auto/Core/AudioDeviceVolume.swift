import CoreAudio
import Foundation

/// Read/write input-scope volume and mute on a specific audio device.
/// Volumes are per-channel; we apply to channel 0 (master) where available.
struct AudioDeviceVolume {

    enum VolumeError: LocalizedError {
        case unsupported
        case osStatus(OSStatus)
        var errorDescription: String? {
            switch self {
            case .unsupported: return "Device does not support this property"
            case .osStatus(let s): return "CoreAudio error \(s)"
            }
        }
    }

    /// Sets input scope volume for a device, clamped 0...1.
    static func setInputVolume(_ device: AudioDevice, volume: Double) throws {
        let clamped = Float32(max(0, min(1, volume)))
        try setVolume(deviceID: device.deviceID, scope: kAudioObjectPropertyScopeInput, volume: clamped)
    }

    /// Sets output scope volume for a device, clamped 0...1.
    static func setOutputVolume(_ device: AudioDevice, volume: Double) throws {
        let clamped = Float32(max(0, min(1, volume)))
        try setVolume(deviceID: device.deviceID, scope: kAudioObjectPropertyScopeOutput, volume: clamped)
    }

    /// Reads current output volume (0...1). Returns nil if the device
    /// doesn't expose a software-readable volume property — e.g. some
    /// pro audio interfaces handle volume in hardware only.
    static func getOutputVolume(_ device: AudioDevice) -> Double? {
        readVolume(deviceID: device.deviceID, scope: kAudioObjectPropertyScopeOutput)
    }

    /// Toggles input mute for a device. Returns the new mute state.
    @discardableResult
    static func toggleInputMute(_ device: AudioDevice) throws -> Bool {
        let current = try readMute(deviceID: device.deviceID, scope: kAudioObjectPropertyScopeInput)
        try writeMute(deviceID: device.deviceID, scope: kAudioObjectPropertyScopeInput, mute: !current)
        return !current
    }

    // MARK: - Private

    private static func setVolume(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, volume: Float32) throws {
        // Try master channel (0), then each channel if needed.
        let candidates: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]
        var lastStatus: OSStatus = noErr
        var anySucceeded = false

        for element in candidates {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr,
                  settable.boolValue else { continue }

            var v = volume
            let status = AudioObjectSetPropertyData(
                deviceID, &address, 0, nil,
                UInt32(MemoryLayout<Float32>.size), &v
            )
            if status == noErr {
                anySucceeded = true
                if element == kAudioObjectPropertyElementMain { return }
            } else {
                lastStatus = status
            }
        }

        if !anySucceeded {
            if lastStatus == noErr { throw VolumeError.unsupported }
            throw VolumeError.osStatus(lastStatus)
        }
    }

    /// Read scalar volume from the master element. Returns nil when no
    /// readable element is present.
    private static func readVolume(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Double? {
        // Same fallback chain as the setter — master then individual channels.
        let candidates: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]
        for element in candidates {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
            if status == noErr {
                return Double(value)
            }
        }
        return nil
    }

    private static func readMute(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { throw VolumeError.unsupported }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { throw VolumeError.osStatus(status) }
        return value != 0
    }

    private static func writeMute(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, mute: Bool) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { throw VolumeError.unsupported }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr,
              settable.boolValue else { throw VolumeError.unsupported }
        var value: UInt32 = mute ? 1 : 0
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
        guard status == noErr else { throw VolumeError.osStatus(status) }
    }
}
