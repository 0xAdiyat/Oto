# Focus & Wellbeing — Shaping Notes

## Scope

Close LookAway feature-parity gaps for the **General** page and the **Focus & Wellbeing** settings group (Screen Breaks, Smart Pause, Wellness Reminders, Stats). The break-cycle core, Smart Pause idle/lock/sleep, stats recording, onboarding, and full-screen break overlay already exist (~85%) — this phase extends, it does not rebuild.

Out of scope (next phase): Behavior & Feedback (Alerts/Nudges, Sounds, Keyboard Shortcuts) and Integrations (iPhone/iPad Sync, Automation).

## Decisions

- **Reminders are floating overlays**, not notifications. Per-reminder Enabled / Size / 9-point Position / Sound, plus common settings (dim screen, keep active during smart-pause, hide in screen recordings, reset after break).
- **Smart Pause sources: reliable fully wired, rest best-effort.** Reliable = deep-focus apps (frontmost bundle ID), calendar (EventKit), typing/dragging suppression. Best-effort = meetings, video, gaming, screen-recording. Full settings UI for all six.
- **Include all heavy items this phase:** Customize break screen, Website usage stats (per-browser via AppleScript), Auto-update via **Sparkle** (accepted dependency tradeoff vs the previous zero-dependency rule), Screen Score + colored rings.
- **Persistence stays additive.** Keep `Oto.wellness.settings.v1`; new fields decode old JSON via custom `init(from:)` with `decodeIfPresent ?? default`. No migration needed.

## Context

- **Visuals:** 5 LookAway screenshots (General, Screen Breaks, Smart Pause, Wellness Reminders, Stats) — see `visuals/`.
- **References:** existing Wellness domain (`Oto/Wellness/**`), settings shell (`Oto/UI/Settings/**`), shared components — see `references.md`.
- **Product alignment:** matches the "Oto wellbeing reframe" direction — two domains behind a Focus/Audio switch.

## Standards Applied

- `global/state-management.md` — `@Observable @MainActor`, AppState composition root, UserDefaults JSON, additive Codable.
- `ui/theming.md` — OtoTheme tokens only, adaptive light/dark, verify both appearances.
- `ui/view-patterns.md` — views by surface under `UI/`, SF Symbols via `OtoIcon`, focus-ring discipline, reuse `IconButton`/hover pattern.
- `architecture/rules-and-audio.md` — layering discipline (keep wellbeing logic in `Wellness/`, UI in `UI/`); never crash on system-API failure, log + degrade.

## Deploy follow-ups (flagged, not in this phase's code)

- Sparkle needs a hosted `appcast.xml` + EdDSA key for real update delivery.
- Website tracking via AppleScript likely requires the app to be non-sandboxed or hold the apple-events automation entitlement.
