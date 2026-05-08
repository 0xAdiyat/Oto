# Design System: Oto

## 1. Visual Theme & Atmosphere

Oto follows a **Spotlight-style aesthetic** — a compact, floating panel that feels native to macOS without being heavy. The overall mood is **dark, airy, and purposeful**: generous whitespace inside constrained panels, translucent frosted-glass surfaces that let the desktop bleed through, and a single vibrant teal accent that anchors all active/positive states.

The UI is **system-adaptive** — it follows macOS Light/Dark appearance automatically. In dark mode it reads as a deep charcoal-glass shell; in light mode the same frosted material shifts to near-white. No forced color scheme is applied anywhere.

Density is deliberately moderate: rows are tall enough to breathe (74 px) but the overall window is narrow (720 px wide) so the app never dominates the desktop. Empty states and loading moments use centered iconography rather than skeleton loaders or spinners.

---

## 2. Color Palette & Roles

### Brand Colors

| Descriptive Name | Hex | Role |
|---|---|---|
| Deep Midnight Navy | `#162C47` | Legacy primary dark surface; used for AirPods device tint |
| Vibrant Teal-Seafoam | `#0F9D8E` | **Primary accent** — active status dots, toggle tint, CTA button tint, enabled-rule action text, selection ring on template cards |
| Warm Marigold Yellow | `#FBC02D` | Built-in / internal device tint only |
| Parchment Cream | `#F9F5EF` | Legacy light surface (retained in palette, not active in main UI) |
| Muted Sage Mist | `#B2D5D1` | Legacy subtle accent (retained, not active in main UI) |
| Muted Ember Red | `#D94D4D` | Warning / disconnect emphasis; intentionally outside the brand palette so errors stand out immediately |

### Adaptive Surface Tokens (follow system appearance)

These are expressed as `Color.primary` at low opacity, so they flip correctly between dark and light mode.

| Token | Opacity | Usage |
|---|---|---|
| `strokeColor` | `Color.primary` × 12% | Hairline border on panels, cards, tiles |
| `dividerColor` | `Color.primary` × 8% | 1 px horizontal rule between sections |
| `rowIdle` | `Color.primary` × 4% | Resting row / chip background |
| `rowHover` | `Color.primary` × 9.5% | Row background on pointer hover |
| `rowSelected` | `Color.primary` × 5.5% | Row background when selected/pressed |
| `iconTile` | `Color.primary` × 6% | Square tile behind device/trigger icons |
| `mutedFG` | `Color.primary` × 58% | Secondary labels, section headers, placeholder text |
| `secondaryFG` | `Color.primary` × 72% | Subtitles, trailing labels, icon buttons at rest |

### Shadow Colors

Shadows are always dark, regardless of theme — providing consistent depth perception in both light and dark mode.

| Token | Value | Usage |
|---|---|---|
| `shadowStrong` | `black` × 22% | Main panel and header capsule drop shadow |
| `shadowMedium` | `black` × 14% | Secondary cards (e.g. rules panel with `strongShadow: false`) |

---

## 3. Typography Rules

All type is set in **SF Pro** (via `.system(size:weight:)`), inheriting macOS default tracking and kerning.

| Role | Size | Weight | Notes |
|---|---|---|---|
| Title / sheet heading | 22 pt | `.semibold` | Top of rule editor and template sheets |
| Input field | 21 pt | varies | Reserved for potential search inputs |
| Header pill label | 17 pt | `.semibold` | "Rules" label in the capsule header |
| Row primary | 14 pt | `.medium` | Trigger description in rule rows |
| Body / form label | 13 pt | `.regular` | Form row labels, empty-state body copy |
| Small / chip | 12 pt | `.medium` | Footer buttons, row sub-labels |
| Meta / caption | 11 pt | `.regular` | Section headers ("Current Input"), status labels, rule counts |
| Micro | 10 pt | `.bold` or `.regular` | Device kind badges ("Active", "Built-in") |

Letter-spacing and line-height are left to SF Pro defaults — no custom tracking is applied. Multi-line text is constrained with `.lineLimit(1)` on row content to preserve single-line density.

---

## 4. Component Styling

### Panels & Sheets
Built with the `materialPanel()` modifier: `.ultraThinMaterial` fill inside a `RoundedRectangle` with **generously rounded corners (24 pt radius)**, a whisper-soft hairline stroke (`strokeColor`), and a diffuse black drop shadow (28 pt blur radius, 18 pt Y offset). This treatment is used for every sheet — rule editor (520 px wide), templates sheet (560 px), profiles sheet, devices sheet.

### Header Capsule (HeaderPill)
A fully pill-shaped bar (680 × 64 pt, `Capsule` shape) using `materialCapsule()` — same frosted material + hairline + strong shadow as panels, but shaped as a continuous pill. Floats above the rules card, giving the app a Spotlight-launcher silhouette.

### Cards (RulesPanel)
Same `materialPanel()` treatment, but with `strongShadow: false` (medium shadow: 24 pt blur, 14 pt Y offset) and a `cardRadius` of **14 pt** — subtly rounded corners, slightly tighter than the outer panel.

### Rule Rows
74 pt tall, 10 pt horizontal padding. Resting state: transparent background. On hover: filled with `rowSelected` (`Color.primary` × 5.5%) inside a 14 pt rounded rectangle — a very gentle lift that feels native. Disabled rules render at 55% opacity, creating a clear "inactive" state without removing the row.

### Trigger Tiles
48 × 48 pt square tiles with **12 pt rounded corners**, `iconTile` fill, and a 60%-opacity `strokeColor` hairline. SF Symbol icons at 20 pt size, rendered at 85% primary opacity (slightly softened from full white/black).

### Icon Buttons (IconButton / HeaderIconButton)
30 pt touch target, icon rendered at 13–14 pt. No border at rest. On hover: subtle `rowHover` fill. Use `OtoIcon(name:size:weight:)` with SF Symbol names.

### Chips & Inline Badges
Capsule-shaped pills (e.g. "Active" status, profile picker label, "Switch" button). Background: `rowIdle`. For the "Active" dot: a 7 pt `otoTeal` circle. For the "Active" text badge: teal at 18% opacity background, full teal foreground.

### Toggle (Rule Enable/Disable)
SwiftUI `.switch` style, `.controlSize(.small)`, tinted with `.otoTeal`. Gives immediate visual confirmation that a rule is live.

### CTA Buttons
`.borderedProminent` style, `.tint(.otoTeal)`. Used for "Add", "Save", "Add Selected" — always positioned trailing in an `HStack` pair with a plain "Cancel" button.

### Form Rows (RuleEditorSheet)
Custom `FormRow` structure: label (88 pt fixed width, `mutedFG` color, 13 pt) flush left; control flush right. Rows separated by 1 pt `dividerColor` hairlines. Last row omits the divider. This replaces SwiftUI's `.formStyle(.grouped)` to match the dark-material aesthetic.

### Dividers (MenuBarView)
1 pt `Rectangle` filled with `dividerColor`, padded 2 pt vertically. Ultra-subtle — more of a breathing spacer than a visible rule.

---

## 5. Layout Principles

**Fixed-width floating panels**: The main window is always 720 pt wide and centers on screen (Spotlight-style). The rules card and header pill are 680 pt — 20 pt inset on each side from the window edge, creating a floating appearance.

**Vertical rhythm via fixed row heights**: Rule rows are 74 pt; device rows use 2 pt vertical padding with consistent icon tile sizing. The rules panel height is computed as `visibleRows × rowHeight + insets`, capping at 5 visible rows before scrolling.

**Generous inset padding**: Sheets use 26 pt all-around padding. The menu bar popover uses 14 pt all-around. Form rows use 10 pt vertical padding. This creates breathing room without wasting space.

**No navigation chrome**: Oto has no sidebar, no toolbar, no title bar. Everything is modal-free except for sheet overlays. The header pill is the only persistent navigation surface.

**Hover-driven affordances**: Action clusters (edit/ellipsis buttons on rule rows) are visible at 72% opacity at rest and full opacity on hover. This keeps the UI clean until the user's attention arrives.

**Adaptive scrolling**: Lists use `ScrollView` + `LazyVStack` with hidden scroll indicators (`.scrollIndicators(.hidden)`), keeping the frosted panel surface uncluttered.

**Animation cadence**:
- Hover transitions: 0.12 s `easeOut` — snappy, immediate response
- Content reveals: 0.18 s `easeOut` — smooth but not sluggish
- Layout trims: 0.22 s `easeOut` — slightly slower for structural changes

**Focus hygiene**: All panel and sheet roots apply `.focusEffectDisabled()` to suppress macOS's default blue focus rectangle, which conflicts with the custom rounded-panel aesthetic.
