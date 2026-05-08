import Foundation
import Combine
import Observation

@Observable
@MainActor
final class RuleStore {
    private(set) var rules: [Rule] = []
    private(set) var fireHistory: [RuleFireEvent] = []
    private(set) var profiles: [Profile] = []
    var activeProfileID: UUID? = nil { didSet { saveProfiles() } }

    /// Undo manager for rule mutations. Public so views can wire
    /// `canUndo`/`canRedo` and trigger undo/redo from a global shortcut.
    /// We keep a per-store manager (rather than the window's) because the
    /// spotlight panel is borderless and AppKit doesn't propagate an
    /// implicit `UndoManager` to that window — we control everything
    /// through an explicit instance.
    @ObservationIgnored let undoManager: UndoManager = {
        let m = UndoManager()
        m.levelsOfUndo = 32 // bounded — rule edits are infrequent and small
        return m
    }()

    /// Bump this when changing the Rule schema. Old data is migrated
    /// in `migrateIfNeeded(from:)`.
    private static let currentSchemaVersion = 4

    private let rulesKey = "Oto.rules.v1"
    private let versionKey = "Oto.rules.schemaVersion"
    private let historyKey = "Oto.rules.fireHistory.v1"
    private let profilesKey = "Oto.profiles.v1"
    private let activeProfileKey = "Oto.activeProfileID.v1"
    private let unparseableBackupKey = "Oto.rules.unparseable.v1"
    private let historyLimit = 100

    init() {
        migrateIfNeeded(from: UserDefaults.standard.integer(forKey: versionKey))
        load()
    }

    // MARK: - Rules

    func add(_ rule: Rule) {
        // Register the inverse *before* mutating so the user-visible action
        // name groups correctly. Inside the undo block we call back into
        // the public delete API, which itself registers a redo (Cocoa's
        // UndoManager treats undo-of-undo as redo automatically).
        let snapshot = rule
        undoManager.registerUndo(withTarget: self) { target in
            target.delete(snapshot)
        }
        undoManager.setActionName("Add Rule")
        rules.append(rule)
        save()
    }

    func update(_ rule: Rule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let previous = rules[idx]
        undoManager.registerUndo(withTarget: self) { target in
            target.update(previous)
        }
        undoManager.setActionName("Edit Rule")
        rules[idx] = rule
        save()
    }

    func delete(_ rule: Rule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let snapshot = rules[idx]
        let originalIndex = idx
        undoManager.registerUndo(withTarget: self) { target in
            target.insert(snapshot, at: originalIndex)
        }
        undoManager.setActionName("Delete Rule")
        rules.remove(at: idx)
        save()
    }

    /// Internal restore helper used by undo. Bypasses the auto-append
    /// behaviour of `add()` so we put the rule back at its original index.
    fileprivate func insert(_ rule: Rule, at index: Int) {
        let clamped = max(0, min(rules.count, index))
        undoManager.registerUndo(withTarget: self) { target in
            target.delete(rule)
        }
        undoManager.setActionName("Delete Rule")
        rules.insert(rule, at: clamped)
        save()
    }

    func toggle(_ rule: Rule) {
        var copy = rule
        copy.enabled.toggle()
        // Use update() so the undo path is consistent — undoing a toggle
        // should restore exactly the prior `enabled` value.
        update(copy)
        // Override action name for clarity in the Edit menu.
        undoManager.setActionName(copy.enabled ? "Enable Rule" : "Disable Rule")
    }

    /// Sets `enabled` on every rule at once. Persists a single undo entry
    /// for the whole batch (snapshot-restore) instead of one per rule —
    /// users expect "Undo Pause All" to flip everything back in one step.
    /// No-ops when no rule's state would change, so the chip's secondary
    /// click on an already-fully-paused list doesn't pollute the undo
    /// stack with a redundant entry.
    func setAllRulesEnabled(_ enabled: Bool) {
        let willMutate = rules.contains { $0.enabled != enabled }
        guard willMutate else { return }
        let snapshot = rules
        undoManager.registerUndo(withTarget: self) { target in
            target.replaceAll(with: snapshot, actionName: enabled ? "Resume All Rules" : "Pause All Rules")
        }
        undoManager.setActionName(enabled ? "Resume All Rules" : "Pause All Rules")
        for i in rules.indices {
            rules[i].enabled = enabled
        }
        save()
    }

    func duplicate(_ rule: Rule) {
        let copy = Rule(trigger: rule.trigger, action: rule.action, enabled: rule.enabled, profileID: rule.profileID)
        let insertionIndex: Int
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            insertionIndex = idx + 1
        } else {
            insertionIndex = rules.count
        }
        undoManager.registerUndo(withTarget: self) { target in
            target.delete(copy)
        }
        undoManager.setActionName("Duplicate Rule")
        rules.insert(copy, at: insertionIndex)
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Snapshot the full ordering before mutating so undo is a single
        // assignment, not a reverse-engineered set of moves.
        let before = rules
        undoManager.registerUndo(withTarget: self) { target in
            target.replaceAll(with: before, actionName: "Move Rule")
        }
        undoManager.setActionName("Move Rule")
        // Manual reorder so we don't have to import SwiftUI here.
        let sortedSrc = source.sorted()
        let moving = sortedSrc.map { rules[$0] }
        // Remove from highest to lowest so indices stay valid.
        for idx in sortedSrc.reversed() { rules.remove(at: idx) }
        // Adjust destination for items removed before it.
        let adjustedDest = destination - sortedSrc.filter { $0 < destination }.count
        rules.insert(contentsOf: moving, at: max(0, min(rules.count, adjustedDest)))
        save()
    }

    /// Internal helper — replaces the entire rule array atomically and
    /// registers the inverse so undo→redo works for ordering changes.
    fileprivate func replaceAll(with newRules: [Rule], actionName: String) {
        let before = rules
        undoManager.registerUndo(withTarget: self) { target in
            target.replaceAll(with: before, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        rules = newRules
        save()
    }

    // MARK: - Profiles

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        saveProfiles()
    }

    func deleteProfile(_ profile: Profile) {
        // Detach rules from this profile so they become always-on.
        for i in rules.indices where rules[i].profileID == profile.id {
            rules[i].profileID = nil
        }
        profiles.removeAll { $0.id == profile.id }
        if activeProfileID == profile.id { activeProfileID = nil }
        save()
        saveProfiles()
    }

    // MARK: - Fire history

    func recordFire(rule: Rule, deviceName: String, outcome: RuleFireOutcome, at date: Date = .now) {
        let event = RuleFireEvent(
            id: UUID(),
            ruleID: rule.id,
            ruleSummary: rule.trigger.displayText,
            deviceName: deviceName,
            firedAt: date,
            outcome: outcome
        )
        fireHistory.insert(event, at: 0)
        if fireHistory.count > historyLimit {
            fireHistory = Array(fireHistory.prefix(historyLimit))
        }
        saveHistory()
    }

    // MARK: - Persistence

    private func load() {
        loadRules()
        loadHistory()
        loadProfiles()
    }

    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return }
        do {
            rules = try JSONDecoder().decode([Rule].self, from: data)
        } catch {
            // Schema mismatch (likely a downgrade). Park the raw blob so we
            // can recover later, then start fresh.
            UserDefaults.standard.set(data, forKey: unparseableBackupKey)
            NSLog("Oto: rules decode failed (\(error)); raw data preserved at \(unparseableBackupKey)")
            rules = []
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([RuleFireEvent].self, from: data) else { return }
        fireHistory = decoded
    }

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
        if let s = UserDefaults.standard.string(forKey: activeProfileKey),
           let uuid = UUID(uuidString: s) {
            activeProfileID = uuid
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: rulesKey)
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(fireHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        if let id = activeProfileID {
            UserDefaults.standard.set(id.uuidString, forKey: activeProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
        }
    }

    /// Stub for future migrations. When schema changes, branch on `oldVersion`,
    /// decode old format, transform, write back under the new key, then bump.
    private func migrateIfNeeded(from oldVersion: Int) {
        if oldVersion == Self.currentSchemaVersion { return }
        // v0 → v1: initial.
        // v1 → v2: added profileID + new RuleAction cases. Codable is
        //          backwards-compatible (profileID is optional, new
        //          enum cases don't appear in old data).
        // v2 → v3: profile.icon switched from SF Symbol names to Lucide
        //          asset names. Rewrite stored profile icons.
        if oldVersion < 3 {
            migrateProfileIconsToLucide()
        }
        // v3 → v4: added `appLaunches` trigger, `setOutputVolume` action,
        // and optional `condition` field. All additive — Codable's
        // optional handling lets existing v3 JSON decode unchanged. No
        // payload rewrite needed; we just bump the version stamp so any
        // future migration knows where the data came from.
        UserDefaults.standard.set(Self.currentSchemaVersion, forKey: versionKey)
    }

    private func migrateProfileIconsToLucide() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              var decoded = try? JSONDecoder().decode([Profile].self, from: data) else { return }
        let map: [String: String] = [
            "circle.grid.2x2": "grid-2x2",
            "briefcase": "briefcase",
            "gamecontroller": "gamepad-2",
            "headphones": "headphones",
            "music.note": "music",
            "mic.fill": "mic",
            "moon.stars": "moon-star",
            "person.wave.2": "user-round"
        ]
        for i in decoded.indices {
            decoded[i].icon = map[decoded[i].icon] ?? "grid-2x2"
        }
        if let out = try? JSONEncoder().encode(decoded) {
            UserDefaults.standard.set(out, forKey: profilesKey)
        }
    }
}

// MARK: - Models

struct Profile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    /// Lucide icon asset name (e.g. "grid-2x2").
    var icon: String

    init(id: UUID = UUID(), name: String, icon: String = "grid-2x2") {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

enum RuleFireOutcome: Codable, Hashable {
    case applied
    case noOp           // rule action is .keepCurrent, intentionally did nothing
    case targetMissing  // target device unavailable
    case failed         // CoreAudio call returned an error
}

struct RuleFireEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let ruleID: UUID
    let ruleSummary: String
    let deviceName: String
    let firedAt: Date
    let outcome: RuleFireOutcome

    /// Backwards-compatible decoding for events written before the
    /// `outcome` field existed.
    init(id: UUID, ruleID: UUID, ruleSummary: String, deviceName: String, firedAt: Date, outcome: RuleFireOutcome) {
        self.id = id
        self.ruleID = ruleID
        self.ruleSummary = ruleSummary
        self.deviceName = deviceName
        self.firedAt = firedAt
        self.outcome = outcome
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ruleID = try c.decode(UUID.self, forKey: .ruleID)
        ruleSummary = try c.decode(String.self, forKey: .ruleSummary)
        deviceName = try c.decode(String.self, forKey: .deviceName)
        firedAt = try c.decode(Date.self, forKey: .firedAt)
        outcome = (try? c.decode(RuleFireOutcome.self, forKey: .outcome)) ?? .applied
    }
}
