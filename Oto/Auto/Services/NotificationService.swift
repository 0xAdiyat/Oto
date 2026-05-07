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
}
