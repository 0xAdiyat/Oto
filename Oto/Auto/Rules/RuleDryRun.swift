import Foundation

enum RuleDryRunOutcome: Hashable {
    case wouldApply
    case wouldSkipCondition
    case inactiveProfile
    case targetMissing
    case invalid
    case conflict

    var title: String {
        switch self {
        case .wouldApply: return "Ready"
        case .wouldSkipCondition: return "Condition not met"
        case .inactiveProfile: return "Inactive profile"
        case .targetMissing: return "Target unavailable"
        case .invalid: return "Incomplete rule"
        case .conflict: return "Conflict possible"
        }
    }

    var historyOutcome: RuleFireOutcome {
        switch self {
        case .wouldApply: return .applied
        case .targetMissing: return .targetMissing
        case .invalid, .conflict: return .failed
        case .wouldSkipCondition, .inactiveProfile: return .noOp
        }
    }
}

struct RuleDryRunResult: Hashable {
    let outcome: RuleDryRunOutcome
    let title: String
    let message: String
    let targetName: String

    var isPositive: Bool { outcome == .wouldApply }
}

@MainActor
enum RuleDryRunner {
    static func evaluate(rule: Rule, monitor: AudioDeviceMonitor, store: RuleStore) -> RuleDryRunResult {
        if let profileID = rule.profileID, profileID != store.activeProfileID {
            let profileName = store.profiles.first(where: { $0.id == profileID })?.name ?? "this profile"
            return RuleDryRunResult(
                outcome: .inactiveProfile,
                title: "Inactive profile",
                message: "This rule belongs to \(profileName). It will only run when that profile is active.",
                targetName: rule.action.displayText
            )
        }

        if let condition = rule.condition, !evaluate(condition: condition, monitor: monitor) {
            return RuleDryRunResult(
                outcome: .wouldSkipCondition,
                title: "Condition not met",
                message: "\(condition.displayText). Oto would skip this rule right now.",
                targetName: rule.action.displayText
            )
        }

        if let missing = missingTarget(for: rule.action, monitor: monitor) {
            return RuleDryRunResult(
                outcome: .targetMissing,
                title: "Target unavailable",
                message: "\(missing) is not currently available, so this rule would not apply.",
                targetName: missing
            )
        }

        let clusters = RuleConflicts.clusters(in: store.rules, activeProfileID: rule.profileID)
        if let conflict = clusters.first(where: { $0.ruleIDs.contains(rule.id) }) {
            return RuleDryRunResult(
                outcome: .conflict,
                title: "Conflict possible",
                message: conflict.explanation,
                targetName: rule.action.displayText
            )
        }

        return RuleDryRunResult(
            outcome: .wouldApply,
            title: "Would apply",
            message: "\(rule.action.timelineText). No device changes were made.",
            targetName: rule.action.displayText
        )
    }

    private static func evaluate(condition: RuleCondition, monitor: AudioDeviceMonitor) -> Bool {
        switch condition {
        case .headphonesNotConnected:
            return !monitor.allDevices.contains(where: { $0.isHeadphoneOutput })
        case .headphonesConnected:
            return monitor.allDevices.contains(where: { $0.isHeadphoneOutput })
        }
    }

    private static func missingTarget(for action: RuleAction, monitor: AudioDeviceMonitor) -> String? {
        switch action {
        case .keepCurrent, .toggleInputMute:
            return monitor.defaultInputDevice == nil ? "Current input" : nil
        case .setInput(let uid, let name):
            return monitor.allDevices.contains(where: { $0.uid == uid && $0.hasInput }) ? nil : name
        case .setOutput(let uid, let name):
            return monitor.allDevices.contains(where: { $0.uid == uid && $0.hasOutput }) ? nil : name
        case .setBoth(let inputUID, let inputName, let outputUID, let outputName):
            if !monitor.allDevices.contains(where: { $0.uid == inputUID && $0.hasInput }) { return inputName }
            if !monitor.allDevices.contains(where: { $0.uid == outputUID && $0.hasOutput }) { return outputName }
            return nil
        case .setInputVolume:
            return monitor.defaultInputDevice == nil ? "Current input" : nil
        case .setOutputVolume:
            return monitor.defaultOutputDevice == nil ? "Current output" : nil
        }
    }
}
