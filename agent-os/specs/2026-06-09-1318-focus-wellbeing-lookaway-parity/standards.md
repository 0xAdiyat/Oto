# Standards for Focus & Wellbeing — LookAway Parity

The following standards apply to this work. Full content reproduced from `agent-os/standards/`.

---

## global/state-management.md

Uses the Swift **`@Observable`** macro (macOS 14+) throughout. **No** `ObservableObject`, `@StateObject`, or `@Published` — the whole stack was migrated and assumes `@Observable`. Never reintroduce them.

### Flow
- `AppState` (`@Observable @MainActor`) is the composition root: it constructs and owns `AudioDeviceMonitor`, `RuleStore`, `RuleEngine`, `AppLaunchMonitor`, `QuietHoursManager`, `DeviceLockManager` in `init`, wiring dependencies once.
- Injected at the top of the hierarchy with `.environment(state)`; consumed via `@Environment(AppState.self)`.
- Add new app-wide services by constructing them in `AppState.init` and starting them after the engine is wired (so re-assertion logic sees a complete pipeline).

### Persistence (RuleStore)
- State persists as **UserDefaults-backed JSON** (`JSONEncoder`/`Decoder`) under namespaced keys (`Oto.rules.v1`, `Oto.profiles.v1`, …).
- Schema changes: bump `currentSchemaVersion`, branch on `oldVersion` in `migrateIfNeeded(from:)`. Prefer additive Codable changes (optional fields / new enum cases decode old data unchanged). On decode failure, park the raw blob under an `…unparseable…` key — never silently drop user data.
- Mutations register an inverse on the explicit `undoManager`. Batch operations snapshot the whole array for a single undo entry, and no-op when nothing would change.

---

## ui/theming.md

All spacing, color, typography, radii, shadow, and animation values live in `Oto/UI/OtoTheme.swift`. **Never hardcode** these in view files — reference a token.

### Tokens
- Brand colors: `Color.otoTeal` (primary accent), `Color.otoNavy`, `Color.otoYellow`, `Color.otoAlert`, `Color.otoSage`, `Color.otoCream`.
- Layout/typography/animation: `OtoUI.*` (e.g. `OtoUI.panelRadius`, `OtoUI.rowHeight`, `OtoUI.mutedFG`, `OtoUI.hoverEase`, `OtoUI.titleSize`).
- Settings-window scope: `OtoSettingsUI.*`.

### Adaptive color is mandatory
The app follows **system appearance** (Light/Dark/Auto). There are **no** `.preferredColorScheme()` or forced `NSAppearance` overrides anywhere — do not add any.
- Build new theme colors with the helpers: `OtoUI.adaptiveTone(lightOpacity:darkOpacity:)`, `Color.adaptive(light:dark:)` / `OtoUI.adaptivePanelTint(light:dark:)`.
- Do **not** use raw `Color.primary` for crisp surfaces/text.
- Foreground tiers: `OtoUI.primaryFG` (titles), `OtoUI.secondaryFG` (subtitles/icons), `OtoUI.mutedFG` (placeholders/section headers).

### Surfaces
- Panels/cards: `.materialPanel(cornerRadius:strongShadow:)`. Capsule: `.materialCapsule()`. Tint stacked in `.background`. Shadows are a dark drop in both themes.

### Verify after any theme change
Toggle System Settings → Appearance → Light / Dark / Auto and confirm no contrast failures.

---

## ui/view-patterns.md

### Structure
Views live under `Oto/UI/`, grouped by surface: `Components/`, `Main/`, `MenuBar/`, `Settings/`. Keep UI in `UI/`; keep audio logic in `Auto/` (no cross-leak). Wellbeing logic stays in `Wellness/`.

### Icons
All icons are **SF Symbols** via `OtoIcon(name:size:weight:)`. Do not add image assets for icons.

### Reusable controls
- `IconButton` / `HeaderIconButton` in `Components/IconButton.swift`.
- Hover pattern: `@State private var isHovering`, `.onHover { isHovering = $0 }`, `.animation(OtoUI.hoverEase, value:)`, fill `OtoUI.rowIdle`→`OtoUI.rowHover`.
- Buttons use `.buttonStyle(.plain)` + `.contentShape(Rectangle())`.

### Focus rings
- Every panel root and sheet must carry `.focusEffectDisabled()`.
- Roots with `Picker(.menu)`/AppKit controls also apply `.suppressAppKitFocusRings()`.

### Sheets (Spotlight panel)
Borderless `NSPanel` can't use system `.sheet` dim — use the in-panel overlay system on `MainWindowView` (`@State var activeSheet`, dismiss with `@Environment(\.otoDismiss)`). The Settings window is a standard window, so normal `.sheet` is fine there.

### Previews
Use helpers in `Oto/UI/PreviewSupport.swift`.

---

## architecture/rules-and-audio.md

### Layering
`Auto/Core/` (CoreAudio), `Auto/Rules/` (rule model + engine), `Auto/Services/` (system integrations). Keep audio logic out of `UI/`. (Wellbeing parallels this: `Wellness/Core`, `Wellness/Models`, `Wellness/UI`.)

### Error handling
System writes throw typed errors. Catch, `NSLog("Oto: …")`, record an outcome — **never crash on a system-API failure**. Applies equally to EventKit, AppleScript, screen-capture, and Sparkle calls in this phase: degrade gracefully when permission is denied or the API fails.
