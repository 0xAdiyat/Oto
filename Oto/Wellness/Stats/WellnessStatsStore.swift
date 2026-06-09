import Foundation
import Observation

/// One day's wellbeing tallies. New fields decode-default to zero so older
/// persisted entries keep loading after the schema grows.
struct DayStats: Codable, Identifiable, Hashable {
    /// Start-of-day, the stable key for the day.
    var date: Date

    // Breaks
    var focusSeconds: Int = 0
    var breaksCompleted: Int = 0       // breaks taken via the overlay ("Oto breaks")
    var breaksSkipped: Int = 0
    var naturalBreaks: Int = 0         // stepped away long enough to count as a break
    var snoozeCount: Int = 0
    var snoozeSeconds: Int = 0
    var remindersShown: Int = 0

    // Screen time
    var screenSeconds: Int = 0
    var longestStretchSeconds: Int = 0
    var stretchTotalSeconds: Int = 0
    var stretchCount: Int = 0

    // Per-app active seconds, keyed by bundle id (+ display names).
    var appSeconds: [String: Int] = [:]
    var appNames: [String: String] = [:]

    var id: Date { date }

    var typicalStretchSeconds: Int {
        stretchCount > 0 ? stretchTotalSeconds / stretchCount : longestStretchSeconds
    }

    // Custom decode so new keys default instead of failing on old data.
    init(date: Date) { self.date = date }

    enum CodingKeys: String, CodingKey {
        case date, focusSeconds, breaksCompleted, breaksSkipped, naturalBreaks
        case snoozeCount, snoozeSeconds, remindersShown
        case screenSeconds, longestStretchSeconds, stretchTotalSeconds, stretchCount
        case appSeconds, appNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        focusSeconds = try c.decodeIfPresent(Int.self, forKey: .focusSeconds) ?? 0
        breaksCompleted = try c.decodeIfPresent(Int.self, forKey: .breaksCompleted) ?? 0
        breaksSkipped = try c.decodeIfPresent(Int.self, forKey: .breaksSkipped) ?? 0
        naturalBreaks = try c.decodeIfPresent(Int.self, forKey: .naturalBreaks) ?? 0
        snoozeCount = try c.decodeIfPresent(Int.self, forKey: .snoozeCount) ?? 0
        snoozeSeconds = try c.decodeIfPresent(Int.self, forKey: .snoozeSeconds) ?? 0
        remindersShown = try c.decodeIfPresent(Int.self, forKey: .remindersShown) ?? 0
        screenSeconds = try c.decodeIfPresent(Int.self, forKey: .screenSeconds) ?? 0
        longestStretchSeconds = try c.decodeIfPresent(Int.self, forKey: .longestStretchSeconds) ?? 0
        stretchTotalSeconds = try c.decodeIfPresent(Int.self, forKey: .stretchTotalSeconds) ?? 0
        stretchCount = try c.decodeIfPresent(Int.self, forKey: .stretchCount) ?? 0
        appSeconds = try c.decodeIfPresent([String: Int].self, forKey: .appSeconds) ?? [:]
        appNames = try c.decodeIfPresent([String: String].self, forKey: .appNames) ?? [:]
    }
}

/// One app's usage for display.
struct AppUsage: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let seconds: Int
    var id: String { bundleID }
}

/// Persists daily wellbeing + screen-time tallies and exposes the rollups that
/// drive the menu-bar Stats tab and Stats settings page. Mirrors the audio
/// domain's `UserDefaults` JSON persistence.
@Observable
@MainActor
final class WellnessStatsStore {
    private static let key = "Oto.wellness.stats.v1"
    private static let maxDays = 120

    private(set) var days: [DayStats]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([DayStats].self, from: data) {
            self.days = decoded
        } else {
            self.days = []
        }
    }

    // MARK: Recording

    func recordBreak(completed: Bool, focusedSeconds: Int) {
        mutateToday { day in
            day.focusSeconds += max(0, focusedSeconds)
            if completed { day.breaksCompleted += 1 } else { day.breaksSkipped += 1 }
        }
    }

    func recordReminder() { mutateToday { $0.remindersShown += 1 } }

    func recordSnooze(minutes: Int) {
        mutateToday { $0.snoozeCount += 1; $0.snoozeSeconds += max(0, minutes) * 60 }
    }

    func recordNaturalBreak() { mutateToday { $0.naturalBreaks += 1 } }

    /// Accumulate active screen time + per-app usage, and bump the longest
    /// stretch if the ongoing one now exceeds it.
    func addScreenTime(seconds: Int, bundleID: String, appName: String, currentStretchSeconds: Int) {
        mutateToday { day in
            day.screenSeconds += seconds
            day.appSeconds[bundleID, default: 0] += seconds
            day.appNames[bundleID] = appName
            day.longestStretchSeconds = max(day.longestStretchSeconds, currentStretchSeconds)
        }
    }

    /// Record a completed focus stretch (used for the "typical stretch" average).
    func endStretch(seconds: Int) {
        guard seconds > 0 else { return }
        mutateToday { day in
            day.stretchTotalSeconds += seconds
            day.stretchCount += 1
            day.longestStretchSeconds = max(day.longestStretchSeconds, seconds)
        }
    }

    private func mutateToday(_ change: (inout DayStats) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = days.firstIndex(where: { $0.date == today }) {
            change(&days[idx])
        } else {
            var fresh = DayStats(date: today)
            change(&fresh)
            days.append(fresh)
        }
        if days.count > Self.maxDays { days = Array(days.suffix(Self.maxDays)) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: Rollups

    var today: DayStats {
        let start = Calendar.current.startOfDay(for: Date())
        return days.first(where: { $0.date == start }) ?? DayStats(date: start)
    }

    var lastSevenDays: [DayStats] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return days.first(where: { $0.date == date }) ?? DayStats(date: date)
        }
    }

    var weekBreaksCompleted: Int { lastSevenDays.reduce(0) { $0 + $1.breaksCompleted } }

    /// Today's apps, busiest first.
    func topApps(limit: Int = 6) -> [AppUsage] {
        let t = today
        return t.appSeconds
            .map { AppUsage(bundleID: $0.key, name: t.appNames[$0.key] ?? $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }

    /// 0–100 "how healthy were your screen habits today" score. Heuristic:
    /// start full, penalise long unbroken stretches (vs the chosen interval)
    /// and skipped breaks; reward natural + taken breaks slightly.
    func screenScore(breakIntervalMinutes: Int) -> Int {
        let t = today
        if t.screenSeconds < 60 { return 100 }   // nothing logged yet
        let interval = Double(max(1, breakIntervalMinutes))
        let longestMin = Double(t.longestStretchSeconds) / 60
        let over = max(0, longestMin - interval)

        var score = 100.0
        score -= over * 0.6
        score -= Double(t.breaksSkipped) * 4
        score += Double(t.breaksCompleted + t.naturalBreaks) * 1.5
        return Int(max(0, min(100, score)).rounded())
    }

    // MARK: Formatting

    static func durationLabel(seconds: Int) -> String {
        if seconds <= 0 { return "–" }
        if seconds < 60 { return "\(seconds)s" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    static func focusLabel(seconds: Int) -> String { durationLabel(seconds: seconds) }
}
