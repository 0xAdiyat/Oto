import CoreAudio
import Foundation

/// A CoreAudio device with its identity, display name, and stream capabilities.
/// Uses `uid` as the stable identity across sessions (AudioDeviceID can change between reboots).
struct AudioDevice: Identifiable, Hashable, Codable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.uid == rhs.uid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

// MARK: - CoreAudio Property Queries

extension AudioDevice {

    static func from(deviceID: AudioDeviceID) -> AudioDevice? {
        guard let uid = stringProperty(of: deviceID, selector: kAudioDevicePropertyDeviceUID),
              let name = stringProperty(of: deviceID, selector: kAudioObjectPropertyName)
        else { return nil }

        let hasInput = hasChannels(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
        let hasOutput = hasChannels(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)

        return AudioDevice(id: deviceID, uid: uid, name: name, hasInput: hasInput, hasOutput: hasOutput)
    }

    // MARK: Private helpers

    private static func stringProperty(of deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { return nil }
        return value as String
    }

    /// Checks kAudioDevicePropertyStreamConfiguration for the given scope
    /// and returns true when at least one buffer has channels.
    private static func hasChannels(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return false }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, buffer) == noErr
        else { return false }

        let bufferList = buffer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(bufferList).contains { $0.mNumberChannels > 0 }
    }
}
