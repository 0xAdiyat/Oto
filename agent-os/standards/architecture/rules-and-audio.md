# Rules Engine & Audio Switching

## Layering
`Auto/Core/` (CoreAudio device monitoring + switching), `Auto/Rules/` (rule model + engine), `Auto/Services/` (system integrations). Keep audio logic out of `UI/`.

## Event flow
`RuleEngine` (`@MainActor`) subscribes via Combine to `AudioDeviceMonitor` (`deviceConnected`/`deviceDisconnected`), `AppLaunchMonitor.appLaunched`, and `NSWorkspace.didWakeNotification`. On an event it filters `RuleStore.rules` and applies matches in order.

Matching (`matchingRules`): rule must be `enabled`, profile must match (`nil` profileID = always-on), trigger predicate true, and `condition` (if any) evaluated **at fire time** against current device state — not at trigger time.

## Timing guards (don't remove without cause)
- **Bluetooth/AirPods connect**: wait `bluetoothSettleDelay` (1.5s) before applying — macOS auto-routes ~0.5–1s post-connect; firing earlier loses the race.
- **System wake**: defer `wakeDelay` (2s) — devices re-enumerate 1–3s after wake.
- **Debounce**: ignore repeat fires of the same rule within `debounceWindow` (3s), tracked per `rule.id`.
- One **coalesced** notification per event batch, not per rule.

## Applying actions
- Adding a trigger/action: add a case to the `RuleTrigger`/`RuleAction` enum and handle it in `RuleEngine.apply(...)` — don't branch on raw strings.
- CoreAudio writes go through stateless `AudioDeviceSwitcher` / `AudioDeviceVolume`; they `throw` typed `OSStatus` errors. Engine catches, `NSLog("Oto: …")`, and records an outcome (`applied` / `noOp` / `targetMissing` / `failed`) via `store.recordFire(...)` — never crash on a CoreAudio failure.
- Resolve target devices by `uid` (stable), keeping a `cachedName` fallback for when the device is absent.

## Testing
No automated suite — verify manually: build/run, connect/disconnect a USB or Bluetooth device, confirm the rule fires once with the correct notification.
