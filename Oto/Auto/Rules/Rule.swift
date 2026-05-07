import Foundation

enum RuleTrigger: Codable, Hashable {
    case deviceConnects(deviceUID: String, deviceName: String)
    case deviceDisconnects(deviceUID: String, deviceName: String)
    case anyBluetoothConnects
    case systemWakes
}

enum RuleAction: Codable, Hashable {
    case setInput(deviceUID: String, deviceName: String)
    case keepCurrent
}

struct Rule: Identifiable, Codable, Hashable {
    var id: UUID
    var trigger: RuleTrigger
    var action: RuleAction
    var enabled: Bool

    init(id: UUID = UUID(), trigger: RuleTrigger, action: RuleAction, enabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
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
        case .keepCurrent: return "Keep current input"
        }
    }

    var prefixText: String {
        switch self {
        case .setInput: return "Set input to"
        case .keepCurrent: return ""
        }
    }
}
