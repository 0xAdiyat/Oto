import AppKit

/// Samples the frontmost browser's active-tab URL and attributes foreground
/// time to its domain (LookAway's "Website usage stats"). Only runs for browsers
/// the user enabled in `WellnessSettings.trackedBrowsers`, and only while that
/// browser is frontmost. Active-tab reads go through AppleScript, which prompts
/// for Automation permission the first time; if denied or scripting fails, the
/// sample is silently dropped (no crash) per the error-handling standard.
@MainActor
final class WebsiteUsageTracker {
    private let store: WellnessStore
    private let usage: WebsiteUsageStore

    private var timer: Timer?
    private let tickSeconds = 5

    init(store: WellnessStore, usage: WebsiteUsageStore) {
        self.store = store
        self.usage = usage
    }

    func start() {
        let timer = Timer(timeInterval: TimeInterval(tickSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func sample() {
        let tracked = store.settings.trackedBrowsers
        guard !tracked.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication,
              let bid = front.bundleIdentifier,
              let browser = tracked.first(where: { $0.bundleID == bid }),
              let urlString = activeTabURL(for: browser),
              let domain = Self.domain(from: urlString)
        else { return }
        usage.addUsage(domain: domain, seconds: tickSeconds)
    }

    private func activeTabURL(for browser: BrowserKind) -> String? {
        let source: String
        if browser.isChromiumFamily {
            source = "tell application id \"\(browser.bundleID)\" to get URL of active tab of front window"
        } else {
            source = "tell application id \"\(browser.bundleID)\" to get URL of front document"
        }
        return Self.runAppleScript(source)
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)
        if error != nil { return nil }   // permission denied / no window / not running
        return output.stringValue
    }

    /// Extract a clean host (`www.` stripped) from a URL string.
    static func domain(from urlString: String) -> String? {
        guard let host = URLComponents(string: urlString)?.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
