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


<claude-mem-context>
# Memory Context

# [Oto] recent context, 2026-05-09 12:42am GMT+6

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (17,471t read) | 432,480t work | 96% savings

### May 8, 2026
S211 Implement three audio management features in the Oto macOS SwiftUI app: speaker safety volume cap on music launch, late-night volume restriction, and input device lock veto (May 8 at 7:13 PM)
794 7:26p 🟣 AudioDeviceMonitor: onDefaultOutputChanged C-Callback Added, Monitor Complete
795 " 🟣 AudioDevice: isHeadphoneOutput Property Added for Speaker Safety Detection
796 " 🟣 Rule.swift: appLaunches Trigger, setOutputVolume Action, and RuleCondition Added
797 7:27p 🟣 AppLaunchMonitor.swift Created: NSWorkspace App Launch Observation
798 " 🟣 RuleEngine: AppLaunchMonitor Dependency Added
799 " 🟣 RuleEngine: appLaunched Subject Subscribed, AppLaunchMonitor Injected via init
800 " 🟣 RuleEngine: handleAppLaunched Implemented for appLaunches Trigger
801 " 🟣 RuleEngine: RuleCondition Evaluation Wired into matchingRules
802 7:28p 🟣 RuleEngine: setOutputVolume Action Implemented in apply()
803 " ✅ RuleStore: Schema Version Bumped to 4 for New Rule Fields
804 " 🟣 QuietHoursManager.swift Created: Late-Night Volume Cap Feature
S212 Analyze the Oto project and identify improvements and new features to build — resulted in implementing three major features (May 8 at 7:29 PM)
805 7:30p 🟣 NotificationService: notifyQuietHoursClamped Added
806 " 🟣 DeviceLockManager.swift Created: Input/Output Device Lock Veto
807 " 🟣 AppState: All Three New Services Wired into App Composition Root
808 " 🟣 Settings: Quiet Hours Tab Added to OtoSettingsView
809 " 🟣 QuietHoursSettingsTab UI Implemented in SettingsScene.swift
810 7:31p 🔵 RulesView: RuleEditorSheet Structure Examined Before Extension
811 " 🔵 RulesView: buildRule() Returns Rule Without condition Field
812 " 🟣 RuleEditorSheet: New State, TriggerKind, ActionKind, and ConditionKind Added
813 " 🟣 RuleEditorSheet: App Picker Row Added for appLaunches Trigger
S213 Fix _NSDetectedLayoutRecursion warning caused by hidden Undo/Redo buttons in MainWindowView (May 8 at 7:36 PM)
814 7:38p 🔴 Fixed _NSDetectedLayoutRecursion from undo/redo keyboard shortcut buttons
815 7:39p 🔄 UndoCommandCarriers extracted as isolated SwiftUI invalidation scope
S214 Analyze project and suggest improvements and new features — resulted in implementing a QuietHoursStatusChip UI component for a SwiftUI app (May 8 at 7:39 PM)
816 7:41p 🔵 Build failed: missing Combine import in MainWindowView.swift
S215 Analyze project and identify improvements and new features to implement (May 8 at 7:42 PM)
817 7:42p 🔵 Critical Disk Space: 98% Full on Mac Dev Machine
818 7:46p 🟣 Batch rule enable/disable with smart undo
819 7:47p 🟣 Dual-mode filter chips with bulk pause/resume actions
820 " 🟣 BulkAction enum with discovery and validity checking
821 " ✅ Scoped animation for filter chip transitions
S216 Analyze Oto project for improvements and implement new features based on analysis (May 8 at 7:47 PM)
822 7:48p 🟣 Quiet hours quick toggle in menu bar
823 7:49p 🟣 Icon-only Quiet Hours toggle for menu bar
S217 Analyze the Oto project and identify improvements and new features (May 8 at 7:49 PM)
S218 Analyze Oto project and implement improvements and new features, focusing on UI refinement and user experience enhancements (May 8 at 7:55 PM)
S219 Analyze the Oto project and identify improvements and new features. Session evolved into systematic UI refinement and implementation of a custom sheet presentation system. (May 8 at 7:57 PM)
S220 Analysis of Oto project with improvements and new features. Session evolved into implementation of custom sheet presentation system with visual refinements. (May 8 at 8:06 PM)
### May 9, 2026
866 12:31a 🟣 Oto Spotlight-Style MainWindowView Complete Rewrite
867 12:32a ✅ UI Color Scheme Change Request: Red → Purple or Logo-Derived Color
868 " 🟣 MainWindowView Refactored to Component-Based Architecture (Second Iteration)
869 12:33a 🔵 Oto App Theme System: otoTeal Is the Primary Accent Color
870 " 🔵 Oto Logo Assets Available in SVG for Color Sampling
871 " 🟣 Oto Spotlight UI Second Iteration Builds Successfully
872 " ✅ otoSettingsSurface Color Updated from Warm Cream to Cool Purple-Tinted Tones
873 12:36a ⚖️ Oto Mac App — UI/UX & Feature Ideation Session
874 " 🔵 Oto Settings UI Architecture — SwiftUI Design System Explored
875 12:37a ✅ OtoTheme.swift — Settings Design Token Refinements
876 " ✅ SettingsScene.swift — Settings UI Polish Pass Applied
877 " 🔵 Remaining OtoUI.mutedFG/secondaryFG References in SettingsScene.swift
878 " ✅ SettingsScene.swift — Full OtoUI Foreground Token Migration Completed
879 12:38a ✅ Oto Debug Build — Settings UI Polish Changes Compile Clean
880 12:40a 🔵 Oto App — Full UI Architecture and Settings Entry Points Mapped
881 " 🔵 MenuBarView.swift — Structure and Remaining Legacy Token Locations Identified
882 " 🔴 MenuBarView — Gear Icon Now Opens Settings Instead of Main Window
883 " ✅ Oto Build Succeeded — MenuBarView Settings Navigation Fix Verified
884 " ✅ OtoTheme.swift — Settings Window Width Reduced to 900pt
885 12:41a ✅ Oto Build Succeeded — 900pt Window Width Change Verified Clean

Access 432k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>