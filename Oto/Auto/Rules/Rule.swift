import Foundation

enum RuleTrigger: Codable, Hashable {
    case deviceConnects(deviceUID: String, deviceName: String)
    case deviceDisconnects(deviceUID: String, deviceName: String)
    case anyBluetoothConnects
    case systemWakes
    /// Fires once when an app transitions from not-running to running.
    /// `bundleID` is the stable identifier; `appName` is the cached
    /// display name for UI.
    case appLaunches(bundleID: String, appName: String)
}

enum RuleAction: Codable, Hashable {
    case setInput(deviceUID: String, deviceName: String)
    case setOutput(deviceUID: String, deviceName: String)
    case setBoth(inputUID: String, inputName: String, outputUID: String, outputName: String)
    case setInputVolume(volume: Double)
    /// Sets the *current default output device's* volume to the given level
    /// (0.0–1.0). Operates on whatever output is default at fire time —
    /// this is intentional so the same rule works whether you're on
    /// AirPods or built-in speakers.
    case setOutputVolume(volume: Double)
    case toggleInputMute
    case keepCurrent
}

/// Gates a rule on top of its trigger. nil = always evaluate. Evaluated
/// at fire time, not at rule-creation time.
enum RuleCondition: Codable, Hashable {
    /// True iff no headphones / earbuds / Bluetooth headset is currently
    /// connected. Used by the canonical Spotify-launch volume safety rule.
    case headphonesNotConnected
    /// True iff at least one headphone-class device is connected.
    case headphonesConnected
}

struct Rule: Identifiable, Codable, Hashable {
    var id: UUID
    var trigger: RuleTrigger
    var action: RuleAction
    var enabled: Bool
    /// nil = always-on regardless of active profile.
    var profileID: UUID?
    /// nil = no extra gating. Codable's optional handling means rules
    /// written before this field existed decode with `condition == nil`.
    var condition: RuleCondition?

    init(
        id: UUID = UUID(),
        trigger: RuleTrigger,
        action: RuleAction,
        enabled: Bool = true,
        profileID: UUID? = nil,
        condition: RuleCondition? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
        self.profileID = profileID
        self.condition = condition
    }
}

extension RuleTrigger {
    var displayText: String {
        switch self {
        case .deviceConnects(_, let name): return "When \(name) connects"
        case .deviceDisconnects(_, let name): return "When \(name) disconnects"
        case .anyBluetoothConnects: return "When any Bluetooth device connects"
        case .systemWakes: return "When system wakes up"
        case .appLaunches(_, let appName): return "When \(appName) launches"
        }
    }
}

extension RuleAction {
    var displayText: String {
        switch self {
        case .setInput(_, let name): return name
        case .setOutput(_, let name): return name
        case .setBoth(_, let inName, _, let outName):
            return inName == outName ? inName : "\(inName) + \(outName)"
        case .setInputVolume(let v): return "input volume \(Int(v * 100))%"
        case .setOutputVolume(let v): return "output volume \(Int(v * 100))%"
        case .toggleInputMute: return "toggle input mute"
        case .keepCurrent: return "Keep current input"
        }
    }

    var prefixText: String {
        switch self {
        case .setInput: return "Set input to"
        case .setOutput: return "Set output to"
        case .setBoth: return "Set input + output to"
        case .setInputVolume: return "Set"
        case .setOutputVolume: return "Set"
        case .toggleInputMute: return ""
        case .keepCurrent: return ""
        }
    }
}

extension RuleCondition {
    var displayText: String {
        switch self {
        case .headphonesNotConnected: return "Only when headphones aren't connected"
        case .headphonesConnected:    return "Only when headphones are connected"
        }
    }
}
