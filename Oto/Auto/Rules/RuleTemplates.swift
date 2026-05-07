import Foundation

/// Generates rule suggestions based on the live device list.
enum RuleTemplates {

    struct Suggestion: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let rules: [Rule]
    }

    static func suggestions(for devices: [AudioDevice]) -> [Suggestion] {
        var out: [Suggestion] = []

        let builtIn = devices.first { $0.kind == .builtIn && $0.hasInput }
        let airPodsInput = devices.first { $0.kind == .airPods && $0.hasInput }
        let airPodsOutput = devices.first { $0.kind == .airPods && $0.hasOutput }

        // Per-device "switch to me on connect" for each external input.
        for d in devices where d.hasInput && d.kind != .builtIn {
            out.append(Suggestion(
                id: UUID(),
                title: "When \(d.name) connects → use it as input",
                subtitle: "Auto-switch to \(d.name) the moment it shows up.",
                rules: [
                    Rule(
                        trigger: .deviceConnects(deviceUID: d.uid, deviceName: d.name),
                        action: .setInput(deviceUID: d.uid, deviceName: d.name)
                    )
                ]
            ))

            if let bi = builtIn {
                out.append(Suggestion(
                    id: UUID(),
                    title: "When \(d.name) disconnects → fall back to \(bi.name)",
                    subtitle: "Stay productive when the external device unplugs.",
                    rules: [
                        Rule(
                            trigger: .deviceDisconnects(deviceUID: d.uid, deviceName: d.name),
                            action: .setInput(deviceUID: bi.uid, deviceName: bi.name)
                        )
                    ]
                ))
            }
        }

        // AirPods: switch input + output together when they connect.
        if let inDev = airPodsInput, let outDev = airPodsOutput {
            out.append(Suggestion(
                id: UUID(),
                title: "When AirPods connect → mic + speakers to AirPods",
                subtitle: "Route both directions to AirPods automatically.",
                rules: [
                    Rule(
                        trigger: .deviceConnects(deviceUID: inDev.uid, deviceName: inDev.name),
                        action: .setBoth(
                            inputUID: inDev.uid, inputName: inDev.name,
                            outputUID: outDev.uid, outputName: outDev.name
                        )
                    )
                ]
            ))
        }

        // System wake → restore preferred default.
        if let pref = devices.first(where: { $0.hasInput && $0.kind != .builtIn }) {
            out.append(Suggestion(
                id: UUID(),
                title: "When Mac wakes up → restore \(pref.name)",
                subtitle: "Catch cases where macOS reverts the default after sleep.",
                rules: [
                    Rule(
                        trigger: .systemWakes,
                        action: .setInput(deviceUID: pref.uid, deviceName: pref.name)
                    )
                ]
            ))
        }

        return out
    }
}
