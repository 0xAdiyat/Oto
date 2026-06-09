# UI Theming & Design Tokens

All spacing, color, typography, radii, shadow, and animation values live in `Oto/UI/OtoTheme.swift`. **Never hardcode** these in view files — reference a token.

## Tokens
- Brand colors: `Color.otoTeal` (primary accent), `Color.otoNavy`, `Color.otoYellow`, `Color.otoAlert`, `Color.otoSage`, `Color.otoCream`.
- Layout/typography/animation: `OtoUI.*` (e.g. `OtoUI.panelRadius`, `OtoUI.rowHeight`, `OtoUI.mutedFG`, `OtoUI.hoverEase`, `OtoUI.titleSize`).
- Settings-window scope: `OtoSettingsUI.*`.

## Adaptive color is mandatory
The app follows **system appearance** (Light/Dark/Auto). There are **no** `.preferredColorScheme()` or forced `NSAppearance` overrides anywhere — do not add any.

- Build new theme colors with the helpers, not raw values:
  - `OtoUI.adaptiveTone(lightOpacity:darkOpacity:)` → black-at-opacity in light, white-at-opacity in dark. Use for strokes/surfaces/foregrounds that flip polarity.
  - `Color.adaptive(light:dark:)` / `OtoUI.adaptivePanelTint(light:dark:)` → distinct light vs dark colors.
- Do **not** use raw `Color.primary` for crisp surfaces/text — it multiplies with macOS `labelColor` (~0.85) and smudges. Use the explicit `adaptiveTone` helpers instead.
- Foreground tiers: `OtoUI.primaryFG` (titles), `OtoUI.secondaryFG` (subtitles/icons), `OtoUI.mutedFG` (placeholders/section headers).

## Surfaces
- Panels/cards: `.materialPanel(cornerRadius:strongShadow:)`. Capsule (header pill): `.materialCapsule()`.
- These stack the tint in `.background` (behind content) so it never dims inner text/icons — keep that pattern if extending.
- Shadows are always a dark drop in both themes (`OtoUI.shadowStrong/Medium`).

## Verify after any theme change
Toggle System Settings → Appearance → Light / Dark / Auto and confirm no white-on-white or black-on-black contrast failures.
