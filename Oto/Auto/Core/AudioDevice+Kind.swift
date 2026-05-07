import CoreAudio
import Foundation
import SwiftUI

enum AudioDeviceKind {
    case builtIn, usb, bluetooth, airPods, headphones, other

    var systemImage: String {
        switch self {
        case .builtIn: return "laptop"
        case .usb: return "mic"
        case .bluetooth: return "bluetooth"
        case .airPods: return "ear"
        case .headphones: return "headphones"
        case .other: return "mic"
        }
    }

    var label: String {
        switch self {
        case .builtIn: return "Built-in"
        case .usb: return "USB"
        case .bluetooth: return "Bluetooth"
        case .airPods: return "AirPods"
        case .headphones: return "Headphones"
        case .other: return "Audio"
        }
    }

    var tint: Color {
        switch self {
        case .builtIn: return .otoYellow
        case .usb: return .otoTeal
        case .bluetooth: return .otoTeal
        case .airPods: return .otoNavy
        case .headphones: return .otoTeal
        case .other: return .otoTeal
        }
    }
}

extension AudioDevice {
    var kind: AudioDeviceKind {
        let transport = transportType
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if name.lowercased().contains("airpods") { return .airPods }
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        default:
            let lower = name.lowercased()
            if lower.contains("airpods") { return .airPods }
            if lower.contains("headphone") { return .headphones }
            return .other
        }
    }

    /// Custom tint based on display name (so e.g. "Blue Yeti" appears red).
    /// Falls back to kind tint.
    var displayTint: Color {
        let lower = name.lowercased()
        if lower.contains("yeti") { return .otoAlert }
        if lower.contains("fifine") { return .otoTeal }
        return kind.tint
    }

    private var transportType: UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return status == noErr ? value : 0
    }
}
