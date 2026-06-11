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

// MARK: - Settings LookAway surfaces

/// LookAway-style surface helpers for the Settings window. The shell and
/// grouped panels stay translucent so the desktop influences the final color,
/// while subtle graphite tints keep text contrast stable.
extension View {
    /// Window-level graphite glass backdrop.
    func otoSettingsBackdrop() -> some View {
        background {
            ZStack {
                VisualEffectBackground(material: .underWindowBackground, isEmphasized: true)
                OtoSettingsUI.windowBase.opacity(0.34)
            }
            .ignoresSafeArea()
        }
    }

    /// Grouped settings panel with a subtle hairline, matching the compact
    /// macOS list cards in the reference.
    func otoSectionCard(cornerRadius: CGFloat = OtoSettingsUI.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .background(OtoSettingsUI.panelSurface, in: shape)
            .overlay { shape.strokeBorder(OtoSettingsUI.cardStroke, lineWidth: 1) }
    }

    /// Flat control surface for link/action pills. `interactive` lifts the fill
    /// slightly for button-like controls.
    func otoControlGlass<S: InsettableShape>(in shape: S, interactive: Bool = false) -> some View {
        background(.ultraThinMaterial, in: shape)
            .background(interactive ? OtoSettingsUI.panelSurfaceRaised : OtoSettingsUI.controlFill, in: shape)
    }

    /// Passthrough retained for call-site compatibility.
    func otoGlassGroup(spacing: CGFloat = OtoSettingsUI.sectionSpacing) -> some View {
        self
    }
}
