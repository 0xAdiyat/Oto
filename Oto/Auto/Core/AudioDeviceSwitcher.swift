import CoreAudio
import Foundation

/// Stateless utilities for switching the system default audio devices
/// and filtering device lists by input/output capability.
struct AudioDeviceSwitcher {

    enum SwitchError: LocalizedError {
        case failedToSet(direction: String, status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .failedToSet(let direction, let status):
                return "Failed to set default \(direction) device (OSStatus \(status))"
            }
        }
    }

    static func setDefaultInput(_ device: AudioDevice) throws {
        try setDefault(device, selector: kAudioHardwarePropertyDefaultInputDevice, direction: "input")
    }

    static func setDefaultOutput(_ device: AudioDevice) throws {
        try setDefault(device, selector: kAudioHardwarePropertyDefaultOutputDevice, direction: "output")
    }

    static func allInputDevices(from devices: [AudioDevice]) -> [AudioDevice] {
        devices.filter(\.hasInput)
    }

    static func allOutputDevices(from devices: [AudioDevice]) -> [AudioDevice] {
        devices.filter(\.hasOutput)
    }

    // MARK: - Private

    private static func setDefault(
        _ device: AudioDevice,
        selector: AudioObjectPropertySelector,
        direction: String
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = device.deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
        guard status == noErr else {
            throw SwitchError.failedToSet(direction: direction, status: status)
        }
    }
}
