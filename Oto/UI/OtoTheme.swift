import SwiftUI

/// Brand palette derived from the Oto logo.
///   Navy   #162C47 — primary dark (legacy)
///   Teal   #0F9D8E — primary accent (also AccentColor)
///   Yellow #FBC02D — secondary accent (legacy)
///   Cream  #F9F5EF — light surface (legacy)
///   Sage   #B2D5D1 — subtle accent (legacy)
///
/// Post-overhaul Oto uses a Spotlight-style aesthetic: dark mode, neutral
/// surfaces over `.ultraThinMaterial`, teal accent only.
extension Color {
    static let otoNavy   = Color(red: 0.086, green: 0.173, blue: 0.278)
    static let otoTeal   = Color(red: 0.059, green: 0.616, blue: 0.557)
    static let otoYellow = Color(red: 0.984, green: 0.753, blue: 0.176)
    static let otoCream  = Color(red: 0.976, green: 0.961, blue: 0.937)
    static let otoSage   = Color(red: 0.698, green: 0.835, blue: 0.820)

    /// Subtle red used for warning/disconnect emphasis (kept outside the
    /// brand palette so accidents stand out).
    static let otoAlert  = Color(red: 0.85, green: 0.30, blue: 0.30)
}

/// Spotlight design tokens. Values mirror media-downloader's window/card/row
/// treatments so Oto's UI inherits the same hierarchy.
enum OtoUI {
    // Window / panel
    static let panelWidth: CGFloat        = 720
    static let pillWidth: CGFloat         = 680
    static let pillHeight: CGFloat        = 64

    // Corner radii
    static let panelRadius: CGFloat       = 24
    static let cardRadius: CGFloat        = 14
    static let chipRadius: CGFloat        = 10
    static let buttonRadius: CGFloat      = 8

    // Borders — black-on-light gives a softer hairline that reads cleanly
    // over `.ultraThinMaterial` in light mode (white-on-dark would also work
    // for dark mode; we force light here).
    static let strokeColor                 = Color.black.opacity(0.10)
    static let dividerColor                = Color.black.opacity(0.07)
    static let strokeWidth: CGFloat        = 1

    // Shadows — slightly softer than the dark-mode variant so the panel
    // doesn't punch a heavy hole in the light wallpaper behind it.
    static let shadowStrong                = Color.black.opacity(0.16)
    static let shadowMedium                = Color.black.opacity(0.10)
    static let shadowStrongRadius: CGFloat = 28
    static let shadowMediumRadius: CGFloat = 24
    static let shadowStrongY: CGFloat      = 18
    static let shadowMediumY: CGFloat      = 14

    // Surface tints (over .ultraThinMaterial)
    static let rowIdle                     = Color.primary.opacity(0.04)
    static let rowHover                    = Color.primary.opacity(0.095)
    static let rowSelected                 = Color.primary.opacity(0.055)
    static let iconTile                    = Color.primary.opacity(0.06)
    static let mutedFG                     = Color.primary.opacity(0.58)
    static let secondaryFG                 = Color.primary.opacity(0.72)

    // Type scale
    static let titleSize: CGFloat          = 22
    static let inputSize: CGFloat          = 21
    static let bodySize: CGFloat           = 15
    static let metaSize: CGFloat           = 13
    static let captionSize: CGFloat        = 12

    // Animation
    static let revealEase                  = Animation.easeOut(duration: 0.18)
    static let trimEase                    = Animation.easeOut(duration: 0.22)
    static let hoverEase                   = Animation.easeOut(duration: 0.12)

    // Row sizing
    static let rowHeight: CGFloat          = 74
    static let iconButtonSize: CGFloat     = 30
    static let triggerTileSize: CGFloat    = 48
}

// MARK: - Reusable view modifiers

extension View {
    /// Spotlight-style material panel: ultraThinMaterial fill + soft white
    /// stroke + diffuse drop shadow. Use for the main rules card and sheets.
    func materialPanel(
        cornerRadius: CGFloat = OtoUI.panelRadius,
        strongShadow: Bool = true
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(OtoUI.strokeColor, lineWidth: OtoUI.strokeWidth)
            }
            .shadow(
                color: strongShadow ? OtoUI.shadowStrong : OtoUI.shadowMedium,
                radius: strongShadow ? OtoUI.shadowStrongRadius : OtoUI.shadowMediumRadius,
                x: 0,
                y: strongShadow ? OtoUI.shadowStrongY : OtoUI.shadowMediumY
            )
    }

    /// Capsule variant of `materialPanel` — used for the header pill.
    func materialCapsule() -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(OtoUI.strokeColor, lineWidth: OtoUI.strokeWidth)
            }
            .shadow(
                color: OtoUI.shadowStrong,
                radius: OtoUI.shadowStrongRadius,
                x: 0,
                y: OtoUI.shadowStrongY
            )
    }
}
