# SwiftUI View Patterns

## Structure
Views live under `Oto/UI/`, grouped by surface: `Components/` (reusable), `Main/` (Spotlight panel), `MenuBar/`, `Settings/`. Keep UI in `UI/`; keep audio logic in `Auto/` (no cross-leak).

## Icons
All icons are **SF Symbols** via the `OtoIcon` wrapper:
```swift
OtoIcon(name: "wand.and.stars", size: 14, weight: .medium)
```
Do not add image assets for icons. SF Symbol names use dot-notation and go at the call site (not stored as constants unless reused across files).

## Reusable controls
- `IconButton` (30×30, idle→hover fill) and `HeaderIconButton` (transparent until hover) in `Components/IconButton.swift`. Reuse these rather than rolling new buttons.
- Hover pattern: `@State private var isHovering`, `.onHover { isHovering = $0 }`, `.animation(OtoUI.hoverEase, value: isHovering)`, fill switches `OtoUI.rowIdle`→`OtoUI.rowHover`.
- Buttons use `.buttonStyle(.plain)` + `.contentShape(Rectangle())`.

## Focus rings
- Every panel root and sheet must carry `.focusEffectDisabled()`.
- For roots containing `Picker(.menu)`/AppKit-bridged controls, also apply `.suppressAppKitFocusRings()` — `focusEffectDisabled()` doesn't reach NSPopUpButton.

## Sheets (Spotlight panel)
The borderless `NSPanel` can't use the system `.sheet` dim (renders a square overlay on rounded corners). Use the in-panel overlay system:
- Present via `@State var activeSheet: ActiveSheet?` on `MainWindowView`.
- New sheet: add an `ActiveSheet` case, a `case` in the content switch, build with `.materialPanel()` + `.focusEffectDisabled()`.
- Dismiss with `@Environment(\.otoDismiss)` (not `\.dismiss`) inside panel sheets.

## Previews
Use the helpers in `Oto/UI/PreviewSupport.swift` so previews get a wired `AppState`.
