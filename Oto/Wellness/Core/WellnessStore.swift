import Foundation
import Observation

/// Owns the persisted `WellnessSettings` for the Wellbeing domain. Mirrors
/// `QuietHoursManager`'s shape: an `@Observable @MainActor` holder whose
/// `settings` value saves to `UserDefaults` on every mutation.
///
/// Settings changes need to ripple into the engine (reschedule the next break,
/// re-arm reminders, re-evaluate Smart Pause). Rather than couple this store to
/// those managers, it exposes `onSettingsChange`; `AppState` wires it to fan the
/// notification out to whichever managers care. Views simply mutate
/// `store.settings.*` and the rest follows.
@Observable
@MainActor
final class WellnessStore {
    private static let key = "Oto.wellness.settings.v1"

    var settings: WellnessSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
            onSettingsChange?()
        }
    }

    /// Set by `AppState` to reschedule dependent managers when settings change.
    /// Not part of the persisted/observed state — a plain coordination hook.
    @ObservationIgnored var onSettingsChange: (() -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(WellnessSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
