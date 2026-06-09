import SwiftUI
import AppKit

/// Centralized translucent-surface layer so the LookAway glass aesthetic stays
/// consistent and the version gating lives in one place.
///
/// Two techniques, per the design:
///   • **Window / sidebar / popover chrome** → `NSVisualEffectView` vibrancy on
///     every macOS version. Large chrome reads best as system vibrancy (Apple's
///     guidance is to use Liquid Glass sparingly, for floating controls — not
///     whole window backgrounds).
///   • **Floating cards** → Liquid Glass (`.glassEffect`) on macOS 26, with a
///     `.ultraThinMaterial` fallback below.
///
/// Both reveal the real desktop through a clear (non-opaque) window — "standard
/// transparent components," no painted backdrop.
///
/// Vibrancy itself comes from `VisualEffectBackground` (the shared
/// `NSVisualEffectView` wrapper); this file adds the convenience modifiers and
/// the Liquid-Glass-vs-material gating for floating cards.

extension View {
    /// Behind-window vibrancy for window/sidebar/popover chrome. Uses system
    /// vibrancy (`NSVisualEffectView`) on every OS version — large chrome reads
    /// best as vibrancy, not Liquid Glass.
    func otoVibrantBackground(_ material: NSVisualEffectView.Material = .underWindowBackground) -> some View {
        background(VisualEffectBackground(material: material, isEmphasized: false).ignoresSafeArea())
    }

    /// Translucent floating card. Liquid Glass on macOS 26, `.ultraThinMaterial`
    /// below. Adds a hairline stroke for edge definition on either path.
    @ViewBuilder
    func otoGlassCard(cornerRadius: CGFloat = OtoSettingsUI.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
                .overlay { shape.strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1) }
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1) }
        }
    }

    /// Translucent capsule (e.g. header pills, segmented controls). Liquid Glass
    /// on macOS 26, `.ultraThinMaterial` below.
    @ViewBuilder
    func otoGlassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).strokeBorder(OtoSettingsUI.glassStroke, lineWidth: 1) }
        }
    }
}
