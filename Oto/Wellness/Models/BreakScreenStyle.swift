import SwiftUI
import AppKit

/// Visual style for the full-screen break overlay — the "Customize break screen"
/// editor in Screen Breaks settings. Persisted inside `WellnessSettings`.
struct BreakScreenStyle: Codable, Hashable {
    enum Background: String, Codable, CaseIterable, Hashable {
        case gradient, solid, image

        var label: String {
            switch self {
            case .gradient: return "Gradient"
            case .solid:    return "Solid color"
            case .image:    return "Image"
            }
        }
    }

    var background: Background
    /// Hex string `#RRGGBB`. Used directly for `.solid`, and as the tint base
    /// the gradient is derived from for `.gradient`.
    var colorHex: String
    /// Security-scoped bookmark for a user-chosen background image (`.image`).
    /// Stored as a bookmark (not a path) so access survives relaunch.
    var imageBookmark: Data?
    var headline: String
    var subtitle: String
    var showClock: Bool

    static let `default` = BreakScreenStyle(
        background: .gradient,
        colorHex: "#0F9D8E",
        imageBookmark: nil,
        headline: "Refuel your focus",
        subtitle: "Look 20 feet away and let your eyes relax.",
        showClock: true
    )

    // MARK: - Rendering helpers

    var baseColor: Color { Color(hexString: colorHex) }

    /// Gradient derived from the chosen color — a darker top to a lighter,
    /// slightly hue-shifted bottom for depth on the break screen.
    var gradient: LinearGradient {
        let ns = (NSColor(baseColor).usingColorSpace(.sRGB)) ?? .systemTeal
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let top = Color(nsColor: NSColor(hue: h, saturation: min(1, s + 0.08), brightness: max(0, b - 0.18), alpha: 1))
        let bottom = Color(nsColor: NSColor(hue: max(0, h - 0.04), saturation: max(0, s - 0.1), brightness: min(1, b + 0.12), alpha: 1))
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Resolve the security-scoped bookmark to an image, if any. Caller is
    /// responsible for the short read; access is stopped immediately after load.
    func resolvedImage() -> NSImage? {
        guard background == .image, let data = imageBookmark else { return nil }
        var stale = false
        // Try a security-scoped resolve (sandboxed build) then a plain one
        // (non-sandboxed), matching how the bookmark was created.
        let url = (try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale))
            ?? (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale))
        guard let url else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return NSImage(contentsOf: url)
    }
}
