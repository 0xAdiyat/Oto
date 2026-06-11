import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class AppState {
    static let firstRunSetupCompletedKey = "Oto.hasCompletedFirstRunSetup.v1"
    /// Marks the LookAway-style wellbeing onboarding as done. This is the
    /// primary first-run flow now; the audio setup lives in Settings.
    static let onboardingCompletedKey = "Oto.onboarding.v2.completed"

    // Audio domain
    let monitor: AudioDeviceMonitor
    let store: RuleStore
    let appLaunchMonitor: AppLaunchMonitor
    let quietHours: QuietHoursManager
    let deviceLock: DeviceLockManager
    private let engine: RuleEngine

    // Wellbeing domain
    let wellness: WellnessStore
    let breakManager: BreakManager
    let wellnessStats: WellnessStatsStore
    let websiteUsage: WebsiteUsageStore
    @ObservationIgnored private let breakOverlay: BreakOverlayController
    @ObservationIgnored private let reminders: WellnessReminderManager
    @ObservationIgnored private let reminderOverlay: ReminderOverlayController
    @ObservationIgnored private let smartPause: SmartPauseMonitor
    @ObservationIgnored private let screenUsage: ScreenUsageMonitor
    @ObservationIgnored private let steppedAway: SteppedAwayController
    @ObservationIgnored private let websiteTracker: WebsiteUsageTracker
    @ObservationIgnored private lazy var onboardingController = OnboardingWindowController(state: self)

    var isShowingFirstRunSetup = false

    init() {
        let monitor = AudioDeviceMonitor()
        let store = RuleStore()
        let appLaunchMonitor = AppLaunchMonitor()
        let quietHours = QuietHoursManager()
        let deviceLock = DeviceLockManager()

        self.monitor = monitor
        self.store = store
        self.appLaunchMonitor = appLaunchMonitor
        self.quietHours = quietHours
        self.deviceLock = deviceLock
        self.engine = RuleEngine(monitor: monitor, store: store, appMonitor: appLaunchMonitor)

        // Wellbeing domain — break cycle, overlay, reminders, smart pause, stats.
        let wellness = WellnessStore()
        let breakManager = BreakManager(store: wellness)
        let breakOverlay = BreakOverlayController(manager: breakManager)
        let wellnessStats = WellnessStatsStore()
        let reminders = WellnessReminderManager(store: wellness, breaks: breakManager)
        let reminderOverlay = ReminderOverlayController()
        let smartPause = SmartPauseMonitor(store: wellness, breaks: breakManager)
        let screenUsage = ScreenUsageMonitor(store: wellness, stats: wellnessStats)
        let steppedAway = SteppedAwayController(manager: breakManager, store: wellness)
        let websiteUsage = WebsiteUsageStore()
        let websiteTracker = WebsiteUsageTracker(store: wellness, usage: websiteUsage)
        self.wellness = wellness
        self.breakManager = breakManager
        self.breakOverlay = breakOverlay
        self.wellnessStats = wellnessStats
        self.websiteUsage = websiteUsage
        self.reminders = reminders
        self.reminderOverlay = reminderOverlay
        self.smartPause = smartPause
        self.screenUsage = screenUsage
        self.steppedAway = steppedAway
        self.websiteTracker = websiteTracker

        // Start the guardrails after the engine is constructed so the
        // re-assertion logic sees a fully-wired audio pipeline.
        quietHours.start(monitor: monitor)
        deviceLock.start(monitor: monitor)

        // Show/tear-down the break overlay (and optional chime) as the manager
        // enters/leaves a break.
        breakManager.onBreakStart = { [breakOverlay, weak wellness, weak screenUsage] in
            breakOverlay.show()
            screenUsage?.noteBreakTaken()
            if wellness?.settings.playBreakStartSound == true { NSSound(named: "Glass")?.play() }
        }
        breakManager.onBreakEnd = { [breakOverlay, weak wellness, weak reminders] in
            breakOverlay.hide()
            reminders?.handleBreakEnded()
            if wellness?.settings.playBreakEndSound == true { NSSound(named: "Tink")?.play() }
        }
        // Reminders present through the floating-overlay controller.
        reminders.presenter = reminderOverlay
        // Heads-up nudge before the screen blurs.
        breakManager.onPreBreakWarning = {
            NotificationService.shared.notifyWellness(
                identifier: "Oto.break.warning",
                title: "Break coming up",
                body: "A screen break starts in about a minute.",
                playSound: false
            )
        }
        // Record finished breaks and shown reminders into daily stats.
        breakManager.onBreakFinished = { [weak wellnessStats] completed, focused in
            wellnessStats?.recordBreak(completed: completed, focusedSeconds: focused)
        }
        reminders.onReminderShown = { [weak wellnessStats] _ in
            wellnessStats?.recordReminder()
        }
        breakManager.onSnooze = { [weak wellnessStats] minutes in
            wellnessStats?.recordSnooze(minutes: minutes)
        }
        // Settings edits ripple into every wellbeing manager.
        wellness.onSettingsChange = { [weak breakManager, weak reminders, weak smartPause] in
            breakManager?.reschedule()
            reminders?.reschedule()
            smartPause?.reschedule()
        }
        // Offer a fresh session when the user returns from a long idle gap.
        screenUsage.onReturnedFromAway = { [weak steppedAway] in steppedAway?.present() }

        breakManager.start()
        reminders.start()
        smartPause.start()
        screenUsage.start()
        websiteTracker.start()
    }

    var inputDevices: [AudioDevice] {
        monitor.allDevices.filter(\.hasInput)
    }

    func switchTo(_ device: AudioDevice) {
        try? AudioDeviceSwitcher.setDefaultInput(device)
    }

    /// Show a reminder overlay immediately (settings "preview" buttons).
    func previewReminder(_ kind: WellnessReminderManager.ReminderKind) {
        reminders.preview(kind)
    }

    func presentFirstRunSetup() {
        isShowingFirstRunSetup = true
    }

    func completeFirstRunSetup() {
        UserDefaults.standard.set(true, forKey: Self.firstRunSetupCompletedKey)
        isShowingFirstRunSetup = false
    }

    // MARK: - Wellbeing onboarding (primary first-run flow)

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
    }

    func presentOnboarding() {
        onboardingController.present()
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        onboardingController.close()
    }
}
