# References for Focus & Wellbeing — LookAway Parity

## Reuse — do not rebuild

### Persistence + observe pattern
- **Location:** `Oto/Wellness/Core/WellnessStore.swift`
- **Pattern:** `@Observable @MainActor` store owning a `Codable` settings value; `settings.didSet → save() (JSON→UserDefaults) + onSettingsChange?()`. Every new settings field rides this store.

### Break engine
- **Location:** `Oto/Wellness/Core/BreakManager.swift`
- **Relevance:** tick-based phase machine (`idle/focusing/onBreak`), snooze/skip/enforcement, side-effect closures (`onBreakStart/End/Finished`, `onPreBreakWarning`). Extend for auto-lock + end-early; do not replace.

### Multi-display overlay windowing
- **Location:** `Oto/Wellness/UI/BreakOverlayController.swift`
- **Relevance:** borderless `.screenSaver`-level NSWindows per display, fade in/out, Escape monitor, private-login screen-lock + `pmset` fallback. Copy windowing approach for the new reminder overlay; reuse the lock helper for `lockMacOnBreakStart`.

### Smart Pause
- **Location:** `Oto/Wellness/Core/SmartPauseMonitor.swift`
- **Relevance:** 5s poll + `NSWorkspace`/distributed-notification observers, `CGEventSource.secondsSinceLastEventType`, drives `BreakManager.setPaused`. Fold new source signals into `recompute()`.

### Reminders
- **Location:** `Oto/Wellness/Core/WellnessReminderManager.swift`
- **Relevance:** posture/blink timers, suppression during break/pause. Rework `fire()` to present overlays instead of `notifyWellness`.

### Stats
- **Location:** `Oto/Wellness/Stats/WellnessStatsStore.swift`, `Oto/Wellness/UI/StatsViews.swift`
- **Relevance:** daily rollup store + `StatTile`/`WeeklyFocusBars`. Reuse tiles/bars for website-usage and score visualizations.

### Settings building blocks
- **Location:** `Oto/UI/Settings/SettingsScene.swift`, `Oto/UI/Settings/WellnessSettingsContent.swift`
- **Relevance:** `SettingsContentSection`, `SettingsFieldRow`, `SettingsLinkButtonContent`, `SettingsTileIcon`, `TimePickerRow`; section enum + router (General + the 4 Focus & Wellbeing panes already registered).

### Shared components
- **Location:** `Oto/UI/Components/OptionChipGrid.swift`, `Oto/UI/Components/SegmentedPill.swift`, `Oto/UI/Components/IconButton.swift`, `Oto/UI/Components/HeaderPill.swift`
- **Relevance:** chips for cadence/interval pickers, segmented toggles, icon buttons, hover affordances.

### Notifications
- **Location:** `Oto/Auto/Services/NotificationService.swift`
- **Relevance:** `notifyWellness(identifier:title:body:playSound:)` — kept as a fallback path.

### Theme
- **Location:** `Oto/UI/OtoTheme.swift`
- **Relevance:** all tokens (`Color.oto*`, `OtoUI.*`, `OtoSettingsUI.*`) + adaptive helpers + `OtoIcon`.

### Settings composition root
- **Location:** `Oto/UI/AppState.swift`
- **Relevance:** construct/start every new store/manager here; extend `wellness.onSettingsChange` chain; wire break/reminder closures.
