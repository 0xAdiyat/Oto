# State Management

Uses the Swift **`@Observable`** macro (macOS 14+) throughout. **No** `ObservableObject`, `@StateObject`, or `@Published` — the whole stack was migrated and assumes `@Observable`. Never reintroduce them.

## Flow
- `AppState` (`@Observable @MainActor`) is the composition root: it constructs and owns `AudioDeviceMonitor`, `RuleStore`, `RuleEngine`, `AppLaunchMonitor`, `QuietHoursManager`, `DeviceLockManager` in `init`, wiring dependencies once.
- Injected at the top of the hierarchy with `.environment(state)`; consumed via `@Environment(AppState.self)`.
- Add new app-wide services by constructing them in `AppState.init` and starting them after the engine is wired (so re-assertion logic sees a complete pipeline).

## Persistence (RuleStore)
- State persists as **UserDefaults-backed JSON** (`JSONEncoder`/`Decoder`) under namespaced keys (`Oto.rules.v1`, `Oto.profiles.v1`, …).
- Schema changes: bump `currentSchemaVersion`, branch on `oldVersion` in `migrateIfNeeded(from:)`. Prefer additive Codable changes (optional fields / new enum cases decode old data unchanged). On decode failure, park the raw blob under an `…unparseable…` key — never silently drop user data.
- Mutations register an inverse on the explicit `undoManager` (the borderless panel gets no implicit one). Batch operations snapshot the whole array for a single undo entry, and no-op when nothing would change (don't pollute the undo stack).
