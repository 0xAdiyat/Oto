import Foundation

/// Browsers Oto can track active-tab usage from (LookAway "Stats" page).
/// Chromium-family browsers share Chrome's AppleScript dictionary; Safari has
/// its own. Persisted (as a `Set`) inside `WellnessSettings.trackedBrowsers`.
enum BrowserKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case safari, chrome, comet, chromium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .safari:   return "Safari"
        case .chrome:   return "Chrome"
        case .comet:    return "Comet"
        case .chromium: return "Chromium"
        }
    }

    /// Bundle identifier used to script / detect the browser.
    var bundleID: String {
        switch self {
        case .safari:   return "com.apple.Safari"
        case .chrome:   return "com.google.Chrome"
        case .comet:    return "ai.perplexity.comet"
        case .chromium: return "org.chromium.Chromium"
        }
    }

    /// SF Symbol used in the browser-toggle list.
    var iconName: String { "globe" }

    /// Whether it speaks Chrome's AppleScript dictionary (`active tab`) rather
    /// than Safari's (`current tab`).
    var isChromiumFamily: Bool { self != .safari }
}
