# AGENTS.md — Oto

Oto is a **macOS-only menu bar app** (Swift / SwiftUI) that automatically switches audio input/output devices based on user-defined rules. It lives entirely in the system menu bar — no Dock icon, no main window chrome — and surfaces a Spotlight-style floating panel on demand.

---

## Project Structure

```
Oto/
├── Oto.xcodeproj/           # Xcode project (no SPM packages, no CocoaPods)
├── Oto/
│   ├── OtoApp.swift         # App entry point, AppDelegate, MenuBarExtra
│   ├── ContentView.swift    # Unused stub (entry is OtoApp)
│   ├── Auto/
│   │   ├── Core/            # AudioDevice, AudioDeviceMonitor, AudioDeviceSwitcher, AudioDeviceVolume, AudioDevice+Kind
│   │   ├── Rules/           # Rule, RuleEngine, RuleStore, RuleTemplates
│   │   └── Services/        # LaunchAtLogin, NotificationService
│   └── UI/
│       ├── AppState.swift   # @Observable root state (injected via .environment)
│       ├── OtoTheme.swift   # All design tokens, Color extensions, materialPanel modifier
│       ├── OtoIcon.swift    # SF Symbol wrapper (OtoIcon view)
│       ├── SpotlightWindowController.swift  # NSPanel-based floating window
│       ├── Components/      # HeaderPill, IconButton
│       ├── Main/            # MainWindowView, RulesView, ProfilesSheet, OtherSections
│       └── MenuBar/         # MenuBarView
├── scripts/
│   └── build-release.sh    # Release build → dist/ (app, zip, DMG)
└── dist/                   # Build output (gitignored)
```

**Platform**: macOS 14+ (Sonoma) — uses `@Observable`, `MenuBarExtra`, and CoreAudio APIs  
**Language**: Swift 5.9+  
**No external dependencies** — pure Apple SDK

---

## Build & Run

### Development (Xcode)

Open `Oto.xcodeproj` in Xcode and press **⌘R** to build and run. The app appears in the menu bar — look for the Oto icon (top right of the screen).

### Release Build (CLI)

```bash
./scripts/build-release.sh
```

Outputs to `dist/`:
- `dist/Oto.app` — the built and ad-hoc signed app
- `dist/Oto.zip` — portable zip (preserves signatures)
- `dist/Oto.dmg` — drag-and-drop installer

Requires `xcbeautify` (optional, falls back gracefully if absent):
```bash
brew install xcbeautify
```

### Direct xcodebuild

```bash
xcodebuild -project Oto.xcodeproj -scheme Oto -configuration Debug build
xcodebuild -project Oto.xcodeproj -scheme Oto -configuration Release build
```

---

## Architecture

### State Management

The app uses the **Swift `@Observable` macro** (iOS 17 / macOS 14 equivalent). There is no `ObservableObject`, no `@StateObject`, no `@Published` — all reactive state flows through:

- `AppState` (`@Observable`) — root state, injected once at the top of the view hierarchy via `.environment(state)` and consumed with `@Environment(AppState.self)`
- `RuleStore` — manages `[Rule]` persistence (UserDefaults-backed JSON)
- `AudioDeviceMonitor` — observes CoreAudio HAL notifications for connect/disconnect events

**Never revert to `ObservableObject`/`@StateObject`** — the whole stack was migrated and assumes `@Observable`.

### Window Model

Oto has two UI surfaces:
1. **MenuBarExtra** (`.window` style) — renders `MenuBarView`, always accessible from the menu bar
2. **SpotlightWindowController** — a borderless `NSPanel` that floats above all windows, presents `MainWindowView`, and dismisses on click-outside or Escape

### Rules Engine

`RuleEngine` listens to `AudioDeviceMonitor` events and evaluates `[Rule]` in order. A rule matches when its `RuleTrigger` fires (device connect/disconnect, any Bluetooth, system wake). On match, `AudioDeviceSwitcher` performs the `RuleAction` (set input, set output, set both, set volume, toggle mute).

---

## Code Conventions

### Icons

All icons use **SF Symbols** via `OtoIcon(name: "sf.symbol.name", size: CGFloat, weight: Font.Weight)`. Do not add image assets for icons. SF Symbol names use dot-notation (e.g. `"wand.and.stars"`, `"cable.connector"`).

### Design Tokens

All spacing, color, typography, and animation values live in `OtoTheme.swift`:
- `Color` extensions: `Color.otoTeal`, `Color.otoNavy`, `Color.otoAlert`, etc.
- `OtoUI` enum: `OtoUI.panelRadius`, `OtoUI.rowHeight`, `OtoUI.mutedFG`, `OtoUI.hoverEase`, etc.
- View modifiers: `.materialPanel()`, `.materialCapsule()`

**Never hardcode colors, corner radii, shadow values, or font sizes** — use `OtoUI.*` or `Color.oto*` tokens.

### Color Scheme

The app follows **system appearance** (Light/Dark/Auto). There are **no** `.preferredColorScheme()` overrides and no `NSAppearance` forced overrides anywhere. All stroke and surface colors use `Color.primary` at low opacity so they adapt automatically.

### Focus Effects

Every panel root and all sheet views must carry `.focusEffectDisabled()` to suppress the macOS default blue focus rectangle. This is already applied to all existing sheets — maintain it on any new sheet or panel root you add.

### Sheets

Sheets are presented via `@State var activeSheet: ActiveSheet?` and `.sheet(item:)` on `MainWindowView`. To add a new sheet: add a case to `ActiveSheet`, add a `case` in the `.sheet(item:)` content switch, and build the sheet view with `.materialPanel()` + `.focusEffectDisabled()`.

### Naming

- Swift files use `PascalCase` for types, `camelCase` for properties/functions
- SF Symbol string literals go in the `OtoIcon` call site, not stored as constants (unless reused across files)
- Rule-related enums: `RuleTrigger`, `RuleAction`, `AudioDeviceKind` — add cases to these rather than branching on raw strings

---

## Testing

There is currently no automated test suite. Verification is manual:

1. Build and run in Xcode
2. Test the menu bar icon appears and the popover opens
3. Open the main Spotlight panel via the gear icon or "Open Oto"
4. Connect/disconnect a USB or Bluetooth audio device and confirm rule evaluation fires
5. Toggle system appearance (System Settings → Appearance → Light / Dark / Auto) and confirm the UI adapts with no white-on-white or black-on-black contrast failures

---

## Common Gotchas

- **Single instance enforcement**: `AppDelegate.applicationWillFinishLaunching` terminates any other running instance of Oto. If a build hangs, kill the old process first.
- **No Dock icon by design**: `NSApp.setActivationPolicy(.accessory)` is set in `applicationDidFinishLaunching`. Do not change this — it is intentional.
- **`applicationShouldTerminateAfterLastWindowClosed` returns `false`**: closing the Spotlight panel does not quit the app. Only "Quit Oto" or ⌘Q from the menu bar popover terminates it.
- **`dist/` is gitignored**: the build script recreates it fresh on each run (`rm -rf "$DIST_DIR"`).
- **Xcode project root**: `Oto.xcodeproj` is at the repo root, not inside the `Oto/` subdirectory. Run `xcodebuild` from the repo root.
- **`xcbeautify` is optional**: the build script pipes through `xcbeautify 2>/dev/null || true`, so it won't fail if the tool isn't installed.

---

## PR Guidelines

- Branch naming: `feat/short-description`, `fix/short-description`, `refactor/short-description`
- Keep UI changes scoped to the `UI/` layer; keep audio logic scoped to `Auto/`
- Any new design token belongs in `OtoTheme.swift`; do not scatter magic numbers across view files
- Run a clean build (`xcodebuild clean build`) before opening a PR
