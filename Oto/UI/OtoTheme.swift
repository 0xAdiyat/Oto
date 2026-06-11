import SwiftUI
import AppKit

/// Brand palette derived from the Oto logo. Each color is **adaptive** — the
/// authentic logo value is used in light mode, and a brightness-shifted
/// counterpart is used in dark mode so contrast stays legible. Consumers
/// always reference the same constant (e.g. `Color.otoNavy`); SwiftUI / AppKit
/// resolve the actual RGB at draw-time based on the effective `NSAppearance`.
///
///                Light-mode hex   Dark-mode hex   Role
///   Navy         #162C47          #6F92C9         Bluetooth, headphones
///   Teal         #0F9D8E          #2DBFAE         Primary accent / USB
///   Yellow       #D49E1A          #FBC02D         Built-in mic, system wake
///   Cream        #F9F5EF          #2A2826         Warm surface
///   Sage         #5B9994          #B2D5D1         AirPods / soft accent
///   Alert        #D94D4D          #E86A6A         Warnings (Yeti, errors)
extension Color {
    static let otoNavy   = adaptive(
        light: NSColor(srgbRed: 0.086, green: 0.173, blue: 0.278, alpha: 1),
        dark:  NSColor(srgbRed: 0.435, green: 0.573, blue: 0.788, alpha: 1)
    )
    static let otoTeal   = adaptive(
        light: NSColor(srgbRed: 0.059, green: 0.616, blue: 0.557, alpha: 1),
        dark:  NSColor(srgbRed: 0.176, green: 0.749, blue: 0.682, alpha: 1)
    )
    static let otoYellow = adaptive(
        light: NSColor(srgbRed: 0.831, green: 0.620, blue: 0.102, alpha: 1),
        dark:  NSColor(srgbRed: 0.984, green: 0.753, blue: 0.176, alpha: 1)
    )
    static let otoCream  = adaptive(
        light: NSColor(srgbRed: 0.976, green: 0.961, blue: 0.937, alpha: 1),
        dark:  NSColor(srgbRed: 0.165, green: 0.157, blue: 0.149, alpha: 1)
    )
    static let otoSage   = adaptive(
        light: NSColor(srgbRed: 0.357, green: 0.600, blue: 0.580, alpha: 1),
        dark:  NSColor(srgbRed: 0.698, green: 0.835, blue: 0.820, alpha: 1)
    )
    static let otoAlert  = adaptive(
        light: NSColor(srgbRed: 0.733, green: 0.247, blue: 0.247, alpha: 1),
        dark:  NSColor(srgbRed: 0.910, green: 0.416, blue: 0.416, alpha: 1)
    )
    static let otoSettingsSurface = adaptive(
        light: NSColor(srgbRed: 0.932, green: 0.936, blue: 0.966, alpha: 1),
        dark:  NSColor(srgbRed: 0.070, green: 0.078, blue: 0.145, alpha: 1)
    )

    // MARK: - Vivid tile palette (LookAway-style settings icons)
    //
    // The settings sidebar / page-header icons render as colourful gradient
    // tiles (`SettingsTileIcon`). These hues are intentionally vivid and varied
    // — one distinct colour per section — independent of the teal brand accent
    // used by controls. Fixed (non-adaptive): the settings window is dark-only.
    static let tilePurple = Color(.sRGB, red: 0.58, green: 0.35, blue: 0.96)
    static let tileGreen  = Color(.sRGB, red: 0.30, green: 0.78, blue: 0.47)
    static let tileIndigo = Color(.sRGB, red: 0.42, green: 0.45, blue: 0.95)
    static let tilePink   = Color(.sRGB, red: 0.96, green: 0.36, blue: 0.62)
    static let tileCoral  = Color(.sRGB, red: 0.96, green: 0.38, blue: 0.36)
    static let tileOrange = Color(.sRGB, red: 0.98, green: 0.62, blue: 0.20)
    static let tileBlue   = Color(.sRGB, red: 0.25, green: 0.58, blue: 0.98)
    static let tileAmber  = Color(.sRGB, red: 0.98, green: 0.78, blue: 0.25)

    /// Build a Color whose underlying NSColor resolves per-appearance. In dark
    /// mode (`darkAqua` / `vibrantDark`) returns `dark`; otherwise `light`.
    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return isDark ? dark : light
        })
    }
}

/// Spotlight design tokens. Values mirror media-downloader's window/card/row
/// treatments so Oto's UI inherits the same hierarchy.
enum OtoUI {
    // Window / panel
    static let panelWidth: CGFloat        = 720
    static let pillWidth: CGFloat         = 680
    static let pillHeight: CGFloat        = 48
    static let spotlightSearchHeight: CGFloat = 44
    static let spotlightFooterHeight: CGFloat = 36
    static let spotlightRowHeight: CGFloat    = 60
    static let spotlightSectionGap: CGFloat   = 14

    // Corner radii
    static let panelRadius: CGFloat       = 14
    static let cardRadius: CGFloat        = 10
    static let chipRadius: CGFloat        = 6
    static let buttonRadius: CGFloat      = 5

    // Borders — `Color.primary` is white in dark mode and black in light mode,
    // so a low-opacity primary stroke reads as a subtle hairline in either
    // theme. Opacities are tuned slightly higher than a pure dark-mode value so
    // light-mode panels still have visible edges against light desktops.
    // Hairlines use a low-opacity neutral that flips polarity per appearance:
    // bright white-at-low-opacity reads on dark panels, dark grey reads on
    // light panels. Raw Color.primary would multiply with macOS's labelColor
    // (~0.85) and smudge — these explicit tones stay crisp.
    static let strokeColor                 = OtoUI.adaptiveTone(lightOpacity: 0.15, darkOpacity: 0.18)
    static let dividerColor                = OtoUI.adaptiveTone(lightOpacity: 0.08, darkOpacity: 0.10)
    static let strokeWidth: CGFloat        = 1

    // Translucent overlay stacked over `.thickMaterial` to push the panel's
    // brightness in the right direction per appearance:
    //   • Dark mode: a black scrim grounds text contrast on saturated
    //     wallpapers (Raycast does the same).
    //   • Light mode: a soft white scrim brightens the panel so it reads
    //     light/airy instead of picking up wallpaper hue.
    static let panelTint                   = OtoUI.adaptivePanelTint(
        light: Color.white.opacity(0.42),
        dark:  Color.black.opacity(0.32)
    )

    // Shadows are always a dark drop, regardless of theme. Slightly heavier
    // than typical so the floating panel separates from light wallpapers too.
    static let shadowStrong                = Color.black.opacity(0.28)
    static let shadowMedium                = Color.black.opacity(0.18)
    static let shadowStrongRadius: CGFloat = 28
    static let shadowMediumRadius: CGFloat = 24
    static let shadowStrongY: CGFloat      = 18
    static let shadowMediumY: CGFloat      = 14

    // Surface tints over the panel — flip polarity per appearance so chip /
    // row backgrounds stay subtly visible against either the dark or light
    // panel without compound-dimming (which Color.primary's labelColor base
    // would cause).
    static let rowIdle                     = OtoUI.adaptiveTone(lightOpacity: 0.05, darkOpacity: 0.08)
    static let rowHover                    = OtoUI.adaptiveTone(lightOpacity: 0.10, darkOpacity: 0.14)
    static let rowSelected                 = OtoUI.adaptiveTone(lightOpacity: 0.07, darkOpacity: 0.10)
    static let iconTile                    = OtoUI.adaptiveTone(lightOpacity: 0.07, darkOpacity: 0.10)
    // Foreground tones — explicit black/white per appearance so we sidestep
    // macOS's labelColor softening (which would dim text down to ~0.85
    // opacity even before our multiplier kicks in).
    static let mutedFG                     = OtoUI.adaptiveTone(lightOpacity: 0.60, darkOpacity: 0.78)
    static let secondaryFG                 = OtoUI.adaptiveTone(lightOpacity: 0.85, darkOpacity: 0.98)
    /// Pure black in light mode, pure white in dark mode. Use for the most
    /// important text (titles, headings) where you want max legibility
    /// without macOS's labelColor softening.
    static let primaryFG                   = OtoUI.adaptiveTone(lightOpacity: 1.0, darkOpacity: 1.0)

    // Type scale
    static let titleSize: CGFloat          = 16
    static let inputSize: CGFloat          = 16
    static let bodySize: CGFloat           = 13
    static let metaSize: CGFloat           = 12
    static let captionSize: CGFloat        = 11

    // Animation
    static let revealEase                  = Animation.easeOut(duration: 0.18)
    static let trimEase                    = Animation.easeOut(duration: 0.22)
    static let hoverEase                   = Animation.easeOut(duration: 0.12)

    // Row sizing
    static let rowHeight: CGFloat          = 66
    static let iconButtonSize: CGFloat     = 30
    static let triggerTileSize: CGFloat    = 48

    // MARK: - Adaptive helpers

    /// Returns black-at-`lightOpacity` in light mode, white-at-`darkOpacity`
    /// in dark mode. Use for surfaces / strokes / foregrounds that need to
    /// flip polarity but stay visually equivalent in both themes.
    static func adaptiveTone(lightOpacity: Double, darkOpacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return isDark
                ? NSColor.white.withAlphaComponent(CGFloat(darkOpacity))
                : NSColor.black.withAlphaComponent(CGFloat(lightOpacity))
        })
    }

    /// Two SwiftUI `Color`s — light and dark — picked by current appearance.
    /// More expressive than `adaptiveTone` when the colours aren't simple
    /// black/white tones (e.g. one tinted, one neutral).
    static func adaptivePanelTint(light: Color, dark: Color) -> Color {
        let lightNS = NSColor(light)
        let darkNS  = NSColor(dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return isDark ? darkNS : lightNS
        })
    }
}

/// Settings window design tokens.
///
/// **Dark-mode only**, by design: a LookAway-style transparent graphite /
/// blue-black settings shell with compact grouped rows, soft glass depth, and
/// colorful square icon tiles. It intentionally uses fixed colors so the
/// Settings window preserves the reference aesthetic in both macOS Light and
/// Dark appearance.
///
/// Surface ladder (darkest → lightest): `windowBase` < `contentSurface` <
/// `sidebarSurface` < `panelSurface` < `panelSurfaceRaised`.
enum OtoSettingsUI {
    // MARK: Layout
    static let windowWidth: CGFloat        = 860
    static let windowHeight: CGFloat       = 690
    static let sidebarWidth: CGFloat       = 230
    static let windowRadius: CGFloat       = 18
    static let cardRadius: CGFloat         = 11
    static let controlRadius: CGFloat      = 9
    static let rowRadius: CGFloat          = 9
    static let contentPadding: CGFloat     = 22
    static let contentMaxWidth: CGFloat    = 560
    static let contentTopPadding: CGFloat  = 22
    static let sectionSpacing: CGFloat     = 22
    static let sidebarSectionSpacing: CGFloat = 16
    static let cardSpacing: CGFloat        = 8
    static let cardPadding: CGFloat        = 10
    static let topBarHeight: CGFloat       = 56
    static let topTabWidth: CGFloat        = 84
    static let topTabHeight: CGFloat       = 46

    // MARK: LookAway graphite glass surfaces
    static let windowBase                  = Color(red: 0.060, green: 0.070, blue: 0.095)
    static let contentSurface              = Color(red: 0.080, green: 0.090, blue: 0.120).opacity(0.30)
    static let sidebarSurface              = Color(red: 0.095, green: 0.105, blue: 0.145).opacity(0.58)
    static let sidebarSurfaceDim           = Color(red: 0.055, green: 0.065, blue: 0.095).opacity(0.48)
    static let panelSurface                = Color(red: 0.145, green: 0.155, blue: 0.195).opacity(0.46)
    static let panelSurfaceRaised          = Color(red: 0.215, green: 0.225, blue: 0.270).opacity(0.56)

    // MARK: Interaction fills
    static let sidebarActive               = Color.white.opacity(0.115)
    static let sidebarHover                = Color.white.opacity(0.060)
    static let rowHover                    = Color.white.opacity(0.045)

    // MARK: Strokes / hairlines
    static let windowBorder                = Color.white.opacity(0.16)
    static let cardStroke                  = Color.white.opacity(0.095)
    static let hairline                    = Color.white.opacity(0.105)

    // MARK: Text
    static let primaryText                 = Color.white.opacity(0.92)
    static let secondaryText               = Color.white.opacity(0.74)
    static let tertiaryText                = Color.white.opacity(0.48)

    // MARK: Legacy aliases (consumed across the wellness panes) — remapped to
    // the new layered palette so every pane inherits the redesign for free.
    static let tabSelected                 = sidebarActive
    static let tabSelectedStroke           = Color.white.opacity(0.08)
    static let tabHover                    = sidebarHover
    static let cardFill                    = panelSurface
    static let controlFill                 = Color.white.opacity(0.07)
    static let subtleFill                  = Color.white.opacity(0.04)
    static let glassStroke                 = cardStroke
    static let strongStroke                = Color.white.opacity(0.13)
    static let glassHighlight              = Color.white.opacity(0.045)
    static let labelFG                     = secondaryText
    static let valueFG                     = primaryText
    static let quietFG                     = tertiaryText
    static let windowShadow                = Color.black.opacity(0.48)
}

// MARK: - Reusable view modifiers

extension View {
    /// Raycast-style material panel: thickMaterial fill + neutral dark tint
    /// stacked as the BACKGROUND (so the tint sits behind content, not over
    /// it — putting the tint in `.overlay` would dim every text/icon inside
    /// the panel by the tint's opacity). Stroke is kept as `.overlay` since
    /// it's a frame around the outside.
    func materialPanel(
        cornerRadius: CGFloat = OtoUI.panelRadius,
        strongShadow: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                ZStack {
                    shape.fill(.thickMaterial)
                    shape.fill(OtoUI.panelTint)
                }
            }
            .overlay {
                shape.strokeBorder(OtoUI.strokeColor, lineWidth: OtoUI.strokeWidth)
            }
            .shadow(
                color: strongShadow ? OtoUI.shadowStrong : OtoUI.shadowMedium,
                radius: strongShadow ? OtoUI.shadowStrongRadius : OtoUI.shadowMediumRadius,
                x: 0,
                y: strongShadow ? OtoUI.shadowStrongY : OtoUI.shadowMediumY
            )
    }

    /// SwiftUI's `.focusEffectDisabled()` does not propagate to AppKit-bridged
    /// controls on macOS — `Picker(.menu)` uses NSPopUpButton, which draws its
    /// own accent-tinted focus ring whenever it's first responder. Apply this
    /// at the root of any sheet/panel that contains pickers/menus to walk the
    /// hosted AppKit tree and force `focusRingType = .none` on every NSControl.
    func suppressAppKitFocusRings() -> some View {
        self.background(FocusRingSuppressor())
    }

    /// Capsule variant of `materialPanel` — used for the header pill.
    /// Tint goes in the BACKGROUND (behind content) so it doesn't dim the
    /// header text/icons.
    func materialCapsule() -> some View {
        let shape = Capsule(style: .continuous)
        return self
            .background {
                ZStack {
                    shape.fill(.thickMaterial)
                    shape.fill(OtoUI.panelTint)
                }
            }
            .overlay {
                shape.strokeBorder(OtoUI.strokeColor, lineWidth: OtoUI.strokeWidth)
            }
            .shadow(
                color: OtoUI.shadowStrong,
                radius: OtoUI.shadowStrongRadius,
                x: 0,
                y: OtoUI.shadowStrongY
            )
    }
}

// MARK: - Custom dismiss environment

/// Callable struct that mirrors SwiftUI's `DismissAction` so existing sheet
/// view code (`@Environment(\.dismiss); dismiss()`) can be migrated by
/// changing one line per call site (`\.otoDismiss` instead of `\.dismiss`).
///
/// Why a custom value: the spotlight panel is a borderless transparent
/// NSPanel, and the system `.sheet` modifier dims the parent window with a
/// hard-edged rectangular overlay that doesn't conform to the panel's
/// rounded corners — visually broken. We replace `.sheet` with an in-panel
/// overlay (see `MainWindowView`), which means SwiftUI's built-in
/// `\.dismiss` no longer flows into our sheets. This env value carries our
/// closure-based dismiss in its place.
struct OtoDismissAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct OtoDismissKey: EnvironmentKey {
    static let defaultValue = OtoDismissAction(action: {})
}

extension EnvironmentValues {
    var otoDismiss: OtoDismissAction {
        get { self[OtoDismissKey.self] }
        set { self[OtoDismissKey.self] = newValue }
    }
}

// MARK: - AppKit focus-ring suppression

/// Invisible NSViewRepresentable that, once mounted into a SwiftUI hierarchy,
/// walks the host window's content view and disables the AppKit focus ring on
/// every NSControl it finds. Re-runs on each SwiftUI update because SwiftUI
/// often rebuilds bridged controls (e.g. when a Picker's selection changes).
private struct FocusRingSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        scheduleSweep(from: v)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleSweep(from: nsView)
    }

    private func scheduleSweep(from anchor: NSView) {
        // Defer to next runloop tick so SwiftUI has finished laying out
        // bridged controls before we walk them.
        DispatchQueue.main.async {
            guard let root = anchor.window?.contentView else { return }
            disableRings(in: root)
        }
    }

    private func disableRings(in view: NSView) {
        if let control = view as? NSControl {
            control.focusRingType = .none
        }
        for sub in view.subviews { disableRings(in: sub) }
    }
}
