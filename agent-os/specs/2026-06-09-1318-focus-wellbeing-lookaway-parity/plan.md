# Focus & Wellbeing — LookAway Parity (Phase 1)

## Context

Oto is being reframed from an audio-automation menu-bar app into a dual-domain app: **Audio automation** + **Focus & Wellbeing** (LookAway-style screen breaks + eye/posture care). The Wellbeing domain's *core* is already built (~85%): break-cycle engine, Smart Pause (idle/lock/sleep), notification-based reminders, stats recording, onboarding, settings shell, full-screen break overlay.

This phase closes the **LookAway feature-parity gaps** across the **General** page and the **Focus & Wellbeing** settings group (Screen Breaks, Smart Pause, Wellness Reminders, Stats). Behavior & Feedback and Integrations are out of scope for this phase.

**Confirmed scope decisions:**
- Reminders → **floating on-screen overlays** (Size + 9-point Position + per-reminder Sound), not notifications.
- Smart Pause → **reliable sources fully wired** (deep-focus apps, calendar, typing/dragging suppression) + **best-effort** for meetings/video/gaming/screen-recording; full UI for all.
- Include **all** heavy items this phase: Customize break screen, Website usage stats, Auto-update (Sparkle), Screen Score + colored rings.

## Tasks

1. Save spec documentation (this folder).
2. Settings model foundation — extend `WellnessSettings` (additive Codable), add `BreakScreenStyle`, `SmartPauseSources`, `ReminderStyle`, `BrowserKind`, General + Stats fields.
3. Screen Breaks completion + Customize break screen.
4. Smart Pause expansion (sources, cooldown, stepped-away).
5. Wellness Reminders → floating overlays + common settings.
6. Website usage stats (per-browser tracker + store + UI).
7. Screen Score + colored rings.
8. General menu-bar live preview + timer style.
9. Updates via Sparkle.
10. AppState wiring, permissions, verification.

See `shape.md` for decisions, `references.md` for reuse, `standards.md` for the rules every task follows.

## Verification

Build via `xcodebuild -scheme Oto -configuration Debug build`; manually exercise each pane (break trigger, deep-focus/calendar pause, reminder overlay, browser stats, score rings, Sparkle dialog); toggle Light/Dark for contrast. Cheap unit tests: settings v1-decode-defaults, long-break cadence, score computation, reminder-position mapping.
