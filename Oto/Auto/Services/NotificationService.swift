import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var didRequestAuth = false

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "Oto.showNotifications") as? Bool ?? true
    }

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Current authorization status — for UI to reflect when a user has
    /// denied or not yet granted permission.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func notifyRuleFired(triggerSummary: String, deviceName: String) {
        guard enabled else { return }
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Oto switched input"
        content.body = "\(triggerSummary) → \(deviceName)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Posts a wellbeing reminder (posture / blink). Separate identifier per
    /// kind so a new reminder of the same kind replaces the previous banner
    /// rather than stacking.
    func notifyWellness(identifier: String, title: String, body: String, playSound: Bool) {
        guard enabled else { return }
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = playSound ? .default : nil

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Posts a notice that the quiet-hours guardrail clamped the user's
    /// volume. Separate from `notifyRuleFired` because this isn't a rule
    /// firing — it's a continuous safety net the user opted in to.
    func notifyQuietHoursClamped(cappedPercent: Int, attemptedPercent: Int) {
        guard enabled else { return }
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Quiet Hours is limiting volume"
        content.body = "Volume was reset to \(cappedPercent)% from \(attemptedPercent)%. Disable Quiet Hours to go higher."
        content.sound = nil // intentionally silent — this is a "shh" moment

        let request = UNNotificationRequest(identifier: "Oto.quietHours", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
