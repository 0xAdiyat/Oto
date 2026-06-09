import Foundation
import Observation

/// One domain's usage for display.
struct DomainUsage: Identifiable, Hashable {
    let domain: String
    let seconds: Int
    var id: String { domain }
}

/// Persists per-domain active-tab time per day (LookAway's "Website usage
/// stats"). Separate from `WellnessStatsStore` because it's opt-in and
/// privacy-sensitive — only browsers the user explicitly enabled are recorded.
/// Mirrors the audio domain's UserDefaults-JSON persistence.
@Observable
@MainActor
final class WebsiteUsageStore {
    private static let key = "Oto.wellness.webusage.v1"
    private static let maxDays = 30

    /// `["yyyy-MM-dd": ["domain": seconds]]`.
    private(set) var days: [String: [String: Int]]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            self.days = decoded
        } else {
            self.days = [:]
        }
    }

    private var todayKey: String { Self.dayFormatter.string(from: Date()) }

    func addUsage(domain: String, seconds: Int) {
        guard !domain.isEmpty, seconds > 0 else { return }
        let key = todayKey
        var day = days[key] ?? [:]
        day[domain, default: 0] += seconds
        days[key] = day
        trimIfNeeded()
        save()
    }

    /// Today's domains, busiest first.
    func topDomains(limit: Int = 8) -> [DomainUsage] {
        (days[todayKey] ?? [:])
            .map { DomainUsage(domain: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }

    var todayTotalSeconds: Int { (days[todayKey] ?? [:]).values.reduce(0, +) }

    private func trimIfNeeded() {
        guard days.count > Self.maxDays else { return }
        let keep = Set(days.keys.sorted().suffix(Self.maxDays))
        days = days.filter { keep.contains($0.key) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func durationLabel(seconds: Int) -> String {
        WellnessStatsStore.durationLabel(seconds: seconds)
    }
}
