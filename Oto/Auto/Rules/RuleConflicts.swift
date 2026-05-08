import Foundation

/// Detects rules whose triggers overlap in a way that would cause a
/// non-deterministic outcome at runtime. The engine evaluates rules in
/// declaration order and debounces per-rule fires for 3 s, so two enabled
/// rules with the same trigger that perform *different* actions race against
/// each other on every event — only the first one in the array actually
/// "wins" (the second is debounced away unless it carries an additive action,
/// e.g. setInputVolume in addition to setInput). Surfacing this lets the
/// user resolve the ambiguity instead of silently relying on rule order.
///
/// Conflicts are scoped to the *active profile filter*: an always-on rule
/// (`profileID == nil`) and a Work-scoped rule with the same trigger don't
/// conflict during the Home profile, but they do during Work. We compute
/// for every (profile, trigger) pair independently.
enum RuleConflicts {

    /// One conflict cluster — every rule in `ruleIDs` shares the same
    /// trigger key but has at least one sibling with a different action.
    struct Cluster: Hashable {
        let triggerKey: TriggerKey
        let ruleIDs: Set<UUID>
        let kind: Kind

        enum Kind: Hashable {
            /// Two rules with the same trigger perform contradictory actions
            /// on the same audio direction (e.g. both set input, but to
            /// different devices).
            case contradictoryActions
            /// Two rules with the same trigger perform the *same* action —
            /// one is redundant.
            case duplicateActions
        }
    }

    /// Stable hashable identity for a trigger, ignoring the human-readable
    /// `deviceName` (which can drift). Two triggers conflict iff their keys
    /// are equal and their owning rules share the same effective profile.
    struct TriggerKey: Hashable {
        let raw: String

        init(_ trigger: RuleTrigger) {
            switch trigger {
            case .deviceConnects(let uid, _):    raw = "connect:\(uid)"
            case .deviceDisconnects(let uid, _): raw = "disconnect:\(uid)"
            case .anyBluetoothConnects:          raw = "anyBluetooth"
            case .systemWakes:                   raw = "wake"
            case .appLaunches(let bundleID, _):  raw = "applaunch:\(bundleID)"
            }
        }
    }

    /// Returns every conflict cluster across the given rules. Disabled rules
    /// are ignored — a disabled duplicate isn't a runtime concern.
    static func clusters(in rules: [Rule]) -> [Cluster] {
        // Group enabled rules by (profileScope, triggerKey). profileScope is
        // `rule.profileID` directly; nil-scope rules are their own bucket
        // because they're always active and conflict with *every* profile-
        // scoped rule sharing the trigger only at evaluation time, where the
        // active profile resolves it. We surface that as a conflict only when
        // the nil-scope rule shares the trigger with another nil-scope rule
        // OR with a profile-scoped rule under the active profile (handled by
        // callers via `clusters(in:activeProfileID:)`).
        groupedClusters(rules: rules.filter(\.enabled)) { rule in
            ProfileBucket(profileID: rule.profileID)
        }
    }

    /// Profile-aware variant: only flag conflicts that would actually fire
    /// together when `activeProfileID` is selected. Rules whose profileID is
    /// nil (always-on) participate in every active profile.
    static func clusters(in rules: [Rule], activeProfileID: UUID?) -> [Cluster] {
        let candidates = rules.filter { rule in
            guard rule.enabled else { return false }
            // Always-on rules participate; profile-scoped rules participate
            // only when their profileID matches the active profile.
            return rule.profileID == nil || rule.profileID == activeProfileID
        }
        // All candidates run under the same active profile, so a single
        // bucket per trigger key is correct.
        return groupedClusters(rules: candidates) { _ in ProfileBucket(profileID: activeProfileID) }
    }

    /// Set of rule IDs that participate in any conflict — convenient for
    /// row-level UI badges.
    static func conflictingRuleIDs(in rules: [Rule], activeProfileID: UUID?) -> Set<UUID> {
        var out: Set<UUID> = []
        for c in clusters(in: rules, activeProfileID: activeProfileID) {
            out.formUnion(c.ruleIDs)
        }
        return out
    }

    // MARK: - Private

    private struct ProfileBucket: Hashable {
        let profileID: UUID?
    }

    private static func groupedClusters(
        rules: [Rule],
        bucket: (Rule) -> ProfileBucket
    ) -> [Cluster] {
        var buckets: [BucketKey: [Rule]] = [:]
        for rule in rules {
            let key = BucketKey(profile: bucket(rule), trigger: TriggerKey(rule.trigger))
            buckets[key, default: []].append(rule)
        }
        var out: [Cluster] = []
        for (key, group) in buckets where group.count >= 2 {
            // Within a group, classify by action overlap.
            let signatures = group.map { ActionSignature($0.action) }
            let unique = Set(signatures)
            // Detect *direction* clashes — two rules both targeting "input"
            // with different devices, even if action enums differ
            // (setInput vs setBoth both write the input slot).
            let directions = group.map { ActionSignature.directionsTouched($0.action) }
            let touchedInput = directions.filter { $0.contains(.input) }.count
            let touchedOutput = directions.filter { $0.contains(.output) }.count

            if unique.count == 1 {
                // Every rule has identical action — pure duplicates.
                out.append(Cluster(
                    triggerKey: key.trigger,
                    ruleIDs: Set(group.map(\.id)),
                    kind: .duplicateActions
                ))
            } else if touchedInput >= 2 || touchedOutput >= 2 {
                // Two or more rules write the same direction — they will
                // race. (One writing input + another writing output is fine
                // — they're additive.)
                out.append(Cluster(
                    triggerKey: key.trigger,
                    ruleIDs: Set(group.map(\.id)),
                    kind: .contradictoryActions
                ))
            }
            // Else: actions touch different directions / non-overlapping
            // mutations (e.g. setInput + setInputVolume) — no conflict.
        }
        return out
    }

    private struct BucketKey: Hashable {
        let profile: ProfileBucket
        let trigger: TriggerKey
    }

    /// Compact, hashable description of an action's *effect*, used to detect
    /// pure duplicates.
    private struct ActionSignature: Hashable {
        let raw: String

        init(_ action: RuleAction) {
            switch action {
            case .setInput(let uid, _):                          raw = "in:\(uid)"
            case .setOutput(let uid, _):                         raw = "out:\(uid)"
            case .setBoth(let i, _, let o, _):                   raw = "in:\(i)|out:\(o)"
            case .setInputVolume(let v):                         raw = "ivol:\(Int(v * 1000))"
            case .setOutputVolume(let v):                        raw = "ovol:\(Int(v * 1000))"
            case .toggleInputMute:                               raw = "mute"
            case .keepCurrent:                                   raw = "keep"
            }
        }

        struct Direction: OptionSet, Hashable {
            let rawValue: Int
            static let input  = Direction(rawValue: 1 << 0)
            static let output = Direction(rawValue: 1 << 1)
        }

        static func directionsTouched(_ action: RuleAction) -> Direction {
            switch action {
            case .setInput, .setInputVolume, .toggleInputMute: return .input
            case .setOutput, .setOutputVolume:                  return .output
            case .setBoth:                                      return [.input, .output]
            case .keepCurrent:                                  return []
            }
        }
    }
}

extension RuleConflicts.Cluster {
    var explanation: String {
        switch kind {
        case .duplicateActions:
            return "These rules share the same trigger and action — one is redundant."
        case .contradictoryActions:
            return "These rules share the same trigger but write the same audio direction differently. Only the first matching rule will win the race."
        }
    }
}
