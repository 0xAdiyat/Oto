import CoreAudio
import Foundation
import SwiftUI

enum AudioDeviceKind {
    case builtIn, usb, bluetooth, airPods, headphones, other

    var systemImage: String {
        switch self {
        case .builtIn: return "laptopcomputer"
        case .usb: return "mic"
        case .bluetooth: return "wave.3.right"
        case .airPods: return "airpods"
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

    /// Per-kind tint drawn from the Oto logo palette. Spread across all 5
    /// brand colors so a glance at the rules list shows device variety
    /// (built-in vs USB vs Bluetooth vs AirPods vs over-ear) rather than a
    /// wall of teal.
    var tint: Color {
        switch self {
        case .builtIn:    return .otoYellow   // warm — laptop mascot ear-tip
        case .usb:        return .otoTeal     // primary brand
        case .bluetooth:  return .otoNavy     // cool — wireless distance
        case .airPods:    return .otoSage     // light blue-green, distinct
        case .headphones: return .otoNavy     // cool — over-ear cans
        case .other:      return .otoTeal
        }
    }
}

extension AudioDevice {
    /// True for any device a user would call "headphones" — covers AirPods,
    /// over-ear Bluetooth cans, and the wired-headphones-on-built-in case
    /// (where macOS still reports built-in transport but a separate device
    /// kind). Used by the `headphonesNotConnected` rule condition.
    ///
    /// Why output-only: an external mic that ships with headphones (e.g.
    /// AirPods mic) does not protect built-in speakers from blasting music.
    /// Only the *output* path matters for the safety guarantee.
    var isHeadphoneOutput: Bool {
        guard hasOutput else { return false }
        switch kind {
        case .airPods, .headphones: return true
        case .bluetooth:
            // Bluetooth speakers also live here; a name heuristic is the
            // only practical signal short of probing AVB descriptors.
            let lower = name.lowercased()
            return !(lower.contains("speaker") || lower.contains("hifi") || lower.contains("homepod"))
        case .builtIn, .usb, .other: return false
        }
    }

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
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : 0
    }
}
