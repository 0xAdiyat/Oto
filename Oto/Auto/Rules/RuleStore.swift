import Foundation
import Combine

@MainActor
final class RuleStore: ObservableObject {
    @Published private(set) var rules: [Rule] = []
    @Published private(set) var fireHistory: [RuleFireEvent] = []

    /// Bump this when changing the Rule schema. Old data is migrated
    /// in `migrateIfNeeded(from:)`.
    private static let currentSchemaVersion = 1

    private let rulesKey = "Oto.rules.v1"
    private let versionKey = "Oto.rules.schemaVersion"
    private let historyKey = "Oto.rules.fireHistory.v1"
    private let historyLimit = 50

    init() {
        migrateIfNeeded(from: UserDefaults.standard.integer(forKey: versionKey))
        load()
    }

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

    func recordFire(rule: Rule, deviceName: String, at date: Date = .now) {
        let event = RuleFireEvent(id: UUID(), ruleID: rule.id, ruleSummary: rule.trigger.displayText, deviceName: deviceName, firedAt: date)
        fireHistory.insert(event, at: 0)
        if fireHistory.count > historyLimit {
            fireHistory = Array(fireHistory.prefix(historyLimit))
        }
        saveHistory()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([Rule].self, from: data) {
            rules = decoded
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([RuleFireEvent].self, from: data) {
            fireHistory = decoded
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

    /// Stub for future migrations. When schema changes, branch on `oldVersion`,
    /// decode old format, transform, write back under the new key, then bump.
    private func migrateIfNeeded(from oldVersion: Int) {
        if oldVersion == Self.currentSchemaVersion { return }
        // No prior versions yet — first install or pre-versioned.
        UserDefaults.standard.set(Self.currentSchemaVersion, forKey: versionKey)
    }
}

struct RuleFireEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let ruleID: UUID
    let ruleSummary: String
    let deviceName: String
    let firedAt: Date
}
