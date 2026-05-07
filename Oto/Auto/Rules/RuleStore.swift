import Foundation
import Combine

@MainActor
final class RuleStore: ObservableObject {
    @Published private(set) var rules: [Rule] = []
    @Published private(set) var fireHistory: [RuleFireEvent] = []
    @Published private(set) var profiles: [Profile] = []
    @Published var activeProfileID: UUID? = nil { didSet { saveProfiles() } }

    /// Bump this when changing the Rule schema. Old data is migrated
    /// in `migrateIfNeeded(from:)`.
    private static let currentSchemaVersion = 3

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
        rules.append(rule)
        save()
    }

    func update(_ rule: Rule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        save()
    }

    func delete(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        save()
    }

    func toggle(_ rule: Rule) {
        var copy = rule
        copy.enabled.toggle()
        update(copy)
    }

    func duplicate(_ rule: Rule) {
        let copy = Rule(trigger: rule.trigger, action: rule.action, enabled: rule.enabled, profileID: rule.profileID)
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules.insert(copy, at: idx + 1)
        } else {
            rules.append(copy)
        }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
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
