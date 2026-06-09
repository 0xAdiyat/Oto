# LookAway Glass Restyle — Design

## Goal

Restyle Oto's UI to LookAway's native-glass aesthetic using **standard transparent macOS/SwiftUI components**. Real window vibrancy (desktop shows through), no painted backdrop, Liquid Glass on macOS 26 with a classic `NSVisualEffectView` fallback below.

## Key technique: wallpaper-backed sections

LookAway gets its "purple" not from a gradient but by sampling the **actual desktop wallpaper** and using it as the background of *specific* sections only — the menu-bar preview strip. Window chrome itself is genuine vibrancy. So two distinct backdrop techniques:

1. **Window/sidebar/card vibrancy** — `NSVisualEffectView` (macOS 14–15) / Liquid Glass (macOS 26). Reveals the real desktop behind translucent windows.
2. **Wallpaper-image section background** — read `NSWorkspace.shared.desktopImageURL(for:)`, render that image (scaled-to-fill, blurred + dark scrim) as the background of designated hero/preview sections. Used where LookAway does — the menu-bar preview — and **nowhere else**.

## Approach (chosen: centralized adaptive glass layer)

A single glass abstraction in `OtoTheme`, so version-gating lives in one place and every surface stays consistent.

### Components

- **`WindowVibrancyView`** (`NSViewRepresentable`) — wraps `NSVisualEffectView`; configurable `material` (`.sidebar`, `.menu`, `.popover`, `.underWindowBackground`, `.hudWindow`), `blendingMode = .behindWindow`, `state = .active`.
- **`OtoGlass` + `.otoGlass(_ role:)` modifier** — role ∈ {`window`, `sidebar`, `card`, `capsule`}. macOS 26 → `.glassEffect(.regular, in: shape)` (Liquid Glass); macOS ≤15 → `WindowVibrancyView` material + hairline stroke. Exact Liquid Glass API pinned via context7 + swiftui-expert at implementation time.
- **`DesktopWallpaperView`** — loads the current screen's wallpaper image (refreshes on `NSWorkspace.activeSpaceDidChangeNotification` / screen change), renders scaled-to-fill with a configurable blur + dark scrim. Background for wallpaper-backed sections.
- **Window helpers** — set `backgroundColor = .clear`, `isOpaque = false`; install a vibrant root content view. Extends the existing `SettingsWindowConfigurator`.

### Per-surface application

1. **Settings window** — clear window bg; sidebar = `.sidebar` vibrancy; content pane = `.underWindowBackground`; section cards via `.otoGlass(card)` (replace opaque `otoSettingsSurface` / `cardFill`). Keep colored `SettingsTileIcon` gradient tiles + hairline strokes; re-tune `OtoSettingsUI` tokens for legibility on glass.
2. **Menu-bar popover** — already `materialPanel`; route inner cards through `.otoGlass(card)`, drop opaque fills. **`MenuBarPreview` background → `DesktopWallpaperView`** (replacing the current fake navy gradient + waveform) to match the screenshot exactly.
3. **Break overlay** — already `.fullScreenUI` blur; polish chrome/typography, keep the text scrim, ensure `BreakScreenStyle` composites cleanly. (Liquid Glass optional on 26.)
4. **Onboarding window** — convert from solid titled window to clear-bg vibrant + `.otoGlass` cards.

### Legibility guardrail

Real transparency can crush contrast. Keep/strengthen text scrims behind dense regions, bump `primaryFG`/`secondaryFG`, and verify Light/Dark over both light and dark wallpapers (per `agent-os/standards/ui/theming.md`). Adaptive tokens stay; no `.preferredColorScheme` overrides.

### Version gating

Centralized in `OtoGlass` via `if #available(macOS 26, *)`. macOS 14–15 path uses `NSVisualEffectView`; macOS 26 uses Liquid Glass. No version checks scattered through views.

## Risks

- **Legibility over busy wallpapers** — mitigated by scrims + stronger foreground tokens; verified by screenshotting the real app.
- **Liquid Glass API exactness on macOS 26** — verified via context7 + swiftui-expert during implementation; classic path is the guaranteed-correct baseline.
- **Wallpaper access under sandbox** — `desktopImageURL(for:)` returns a path the sandbox may not read directly; fall back to `NSWorkspace` desktop picture or a tasteful gradient if the image can't be loaded. Confirm at implementation.

## Verification

Build (`xcodebuild`), launch the real app, screenshot Settings / menu-bar popover / break overlay / onboarding in Light + Dark over a light and a dark wallpaper. Confirm: desktop bleed visible, wallpaper-backed preview matches the screenshot, no contrast failures, Liquid Glass on 26 and classic vibrancy below.
