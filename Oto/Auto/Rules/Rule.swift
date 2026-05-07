import Foundation

enum RuleTrigger: Codable, Hashable {
    case deviceConnects(deviceUID: String, deviceName: String)
    case deviceDisconnects(deviceUID: String, deviceName: String)
    case anyBluetoothConnects
    case systemWakes
}

enum RuleAction: Codable, Hashable {
    case setInput(deviceUID: String, deviceName: String)
    case setOutput(deviceUID: String, deviceName: String)
    case setBoth(inputUID: String, inputName: String, outputUID: String, outputName: String)
    case setInputVolume(volume: Double)
    case toggleInputMute
    case keepCurrent
}

struct Rule: Identifiable, Codable, Hashable {
    var id: UUID
    var trigger: RuleTrigger
    var action: RuleAction
    var enabled: Bool
    /// nil = always-on regardless of active profile.
    var profileID: UUID?

    init(id: UUID = UUID(), trigger: RuleTrigger, action: RuleAction, enabled: Bool = true, profileID: UUID? = nil) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
        self.profileID = profileID
    }
}

extension RuleTrigger {
    var displayText: String {
        switch self {
        case .deviceConnects(_, let name): return "When \(name) connects"
        case .deviceDisconnects(_, let name): return "When \(name) disconnects"
        case .anyBluetoothConnects: return "When any Bluetooth device connects"
        case .systemWakes: return "When system wakes up"
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
        case .toggleInputMute: return ""
        case .keepCurrent: return ""
        }
    }
}
