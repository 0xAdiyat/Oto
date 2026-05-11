<a name="oto-top"></a>

<h1 align="center">Oto</h1>
<br>
<p align="center">
  <img src="https://github.com/0xAdiyat/Oto/blob/main/Oto/Assets.xcassets/LogoFull.imageset/logo-full-oto-dark.svg?raw=true" alt="Oto Logo" width="300">
</p>

<p align="center">
  A macOS menu bar app that automatically switches your audio input and output devices based on rules you define — so your mic and speakers always follow you.
</p>

<p align="center">
<br />
  <a href="https://github.com/0xAdiyat/Oto/"><strong>EXPLORE ● THE DOCS</strong></a>
  <br />
  <br />
  <a href="https://github.com/0xAdiyat/Oto/releases">Download</a>
  ·
  <a href="https://github.com/0xAdiyat/Oto/issues/new">Report Bug</a>
  ·
  <a href="https://github.com/0xAdiyat/Oto/issues/new">Request Feature</a>
</p>

<br>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#oto-top">Oto</a></li>
    <ul>
      <li><a href="#platform-support">Platform Support</a></li>
      <li><a href="#why-oto-exists">Why Oto Exists</a></li>
      <li><a href="#features">Features</a></li>
      <li><a href="#architecture">Architecture</a></li>
      <li><a href="#folder-structure">Folder Structure</a></li>
      <li><a href="#getting-started">Getting Started</a></li>
      <li><a href="#contributing">Contributing</a></li>
      <li><a href="#author">Author</a></li>
    </ul>
  </ol>
</details>

---

> [!IMPORTANT]
> ## `💻` `Platform Support`
> - [ ] iOS
> - [ ] iPadOS
> - [x] macOS 14+ (Sonoma)
> - [ ] Windows
> - [ ] Linux

---

## `📽️` `Screenshots`

Menu Bar             |  Spotlight Panel       |   New Rule
:-------------------------:|:-------------------------:|:-------------------------:|
![Menu Bar](https://github.com/0xAdiyat/Oto/blob/main/screenshots/menu-bar.png?raw=true)|![Spotlight Panel](https://github.com/0xAdiyat/Oto/blob/main/screenshots/main-spotlight-screen.png?raw=true)|![New Rule](https://github.com/0xAdiyat/Oto/blob/main/screenshots/new-rule.png?raw=true)|

Devices             |  Empty State
:-------------------------:|:-------------------------:|
![Devices](https://github.com/0xAdiyat/Oto/blob/main/screenshots/devices.png?raw=true)|![Empty State](https://github.com/0xAdiyat/Oto/blob/main/screenshots/empty-state.png?raw=true)|

---

## `💡` `Why Oto Exists`

> You have a dedicated external mic. It sounds great. You use it for every call, every recording, every voice message.
>
> Then you connect your AirPods — and macOS silently switches your default input to the AirPods mic. Mid-call. Without asking.
>
> Now you're diving into System Settings, hunting through Audio preferences, switching it back — while the other person on the call wonders why you suddenly sound like you're in a tunnel.
>
> **Oto fixes this.** Set a rule once: *"When any Bluetooth device connects, keep my mic as the input."* Oto watches in the background and enforces it the moment macOS tries to override your preference. Your dedicated mic stays your default — no matter how many headphones, AirPods, or Bluetooth devices you plug in.

---

## `⚙️` `Features`

- [x] **Rule-Based Audio Switching:**
  - Define rules that fire when a device connects, disconnects, any Bluetooth device connects, or the system wakes from sleep.
  - Each rule maps a trigger to an action — switch input, switch output, switch both simultaneously, set input volume, or toggle input mute.

- [x] **AirPods & Bluetooth Smart Routing:**
  - A dedicated settle delay ensures Oto's rules fire *after* macOS auto-routing completes, eliminating the race condition where macOS overrides your preferred device.
  - "Any Bluetooth connects" trigger lets you set a blanket rule for any Bluetooth headset without naming a specific device.

- [x] **Rule Templates:**
  - Context-aware suggestions generated from your currently connected device list.
  - One-tap presets for common scenarios: "When AirPods connect → route mic + speakers to AirPods", "When USB mic connects → use it as input", "When system wakes → restore preferred device".

- [x] **Profiles:**
  - Group rules under named profiles (e.g. Work, Home, Recording Studio).
  - Rules can be scoped to a specific profile or set to always-on regardless of the active profile.

- [x] **Spotlight-Style Floating Panel:**
  - A borderless `NSPanel` that floats above all windows, centered on screen — like Spotlight, but for audio routing.
  - Dismisses automatically on click-outside or Escape.

- [x] **Menu Bar Popover:**
  - Lives entirely in the system menu bar — no Dock icon, no persistent window.
  - Quick access to your current audio device, active rules, and app controls without leaving your workflow.

- [x] **Launch at Login:**
  - Opt-in background launch so Oto is always running when your Mac is.

- [x] **System Appearance Adaptive:**
  - Fully follows macOS Light / Dark / Auto appearance. No forced color scheme — the frosted-glass UI shifts naturally between modes.

- [x] **Bluetooth Devices Inspector:**
  - The Devices sheet lists all currently connected Bluetooth peripherals — keyboards, mice, headsets, game controllers — alongside the audio device list.
  - Inferred from the IOBluetooth Class-of-Device bits, so each device gets the right SF Symbol (keyboard, mouse, headphones, gamecontroller, …) automatically.

- [x] **Zero External Dependencies:**
  - Pure Apple SDK — CoreAudio, SwiftUI, `@Observable`. No Swift packages, no CocoaPods, no Carthage.

- [x] **Notifications:**
  - Optional system notifications when rules fire, so you know exactly what switched and why.

---

## `🏛️` `Architecture`

> [!NOTE]
> ### State Management — `@Observable`
> Oto uses the **Swift `@Observable` macro** (macOS 14 equivalent). There is no `ObservableObject`, no `@StateObject`, no `@Published` — all reactive state flows through:
> - `AppState` (`@Observable`) — root state, injected once via `.environment(state)` and consumed with `@Environment(AppState.self)`
> - `RuleStore` — manages `[Rule]` persistence (UserDefaults-backed JSON)
> - `AudioDeviceMonitor` — observes CoreAudio HAL HAL property listener notifications for connect / disconnect events via a C-callback bridge
>
> ### Window Model — Two UI Surfaces
> 1. **MenuBarExtra** (`.window` style) — renders `MenuBarView`, always accessible from the menu bar
> 2. **SpotlightWindowController** — a borderless `NSPanel` that floats above all windows, presents `MainWindowView`, and dismisses on click-outside or Escape
>
> ### Rules Engine
> `RuleEngine` subscribes to `AudioDeviceMonitor` events and evaluates `[Rule]` in priority order. A rule matches when its `RuleTrigger` fires. On match, `AudioDeviceSwitcher` performs the `RuleAction` against the CoreAudio HAL. A debounce + Bluetooth settle delay prevents macOS auto-routing from racing against Oto's own device switch.
>
> ### Design System
> All spacing, color, typography, and animation constants live in `OtoTheme.swift` as `OtoUI.*` tokens and `Color.oto*` extensions. The `materialPanel()` and `materialCapsule()` view modifiers express the frosted-glass `.ultraThinMaterial` surface used throughout the app.

---

## `🗂️` `Folder Structure`

```
Oto/
├── Oto.xcodeproj/
├── Oto/
│   ├── OtoApp.swift                      # App entry point, AppDelegate, MenuBarExtra
│   ├── ContentView.swift                 # Unused stub
│   ├── Auto/
│   │   ├── Core/
│   │   │   ├── AudioDevice.swift         # Device model
│   │   │   ├── AudioDevice+Kind.swift    # Kind classification (builtIn, airPods, bluetooth, usb, …)
│   │   │   ├── AudioDeviceMonitor.swift  # CoreAudio HAL property listeners
│   │   │   ├── AudioDeviceSwitcher.swift # HAL write calls to switch default device
│   │   │   └── AudioDeviceVolume.swift   # Input volume + mute control
│   │   ├── Rules/
│   │   │   ├── Rule.swift                # RuleTrigger, RuleAction, Rule model
│   │   │   ├── RuleEngine.swift          # Evaluates rules on device events
│   │   │   ├── RuleStore.swift           # Persistence (UserDefaults JSON)
│   │   │   └── RuleTemplates.swift       # Context-aware one-tap rule suggestions
│   │   └── Services/
│   │       ├── LaunchAtLogin.swift
│   │       └── NotificationService.swift
│   └── UI/
│       ├── AppState.swift                # @Observable root state
│       ├── OtoTheme.swift                # Design tokens, Color extensions, view modifiers
│       ├── OtoIcon.swift                 # SF Symbol wrapper view
│       ├── SpotlightWindowController.swift
│       ├── Components/
│       │   ├── HeaderPill.swift          # Capsule header bar
│       │   └── IconButton.swift
│       ├── Main/
│       │   ├── MainWindowView.swift      # Spotlight panel root
│       │   ├── RulesView.swift           # Rules list + editor sheet
│       │   ├── ProfilesSheet.swift
│       │   └── OtherSections.swift       # Devices + Settings sections
│       └── MenuBar/
│           └── MenuBarView.swift         # Menu bar popover
├── scripts/
│   └── build-release.sh                  # → dist/ (app, zip, DMG)
└── dist/                                 # Build output (gitignored)
```

---

## `💨` `Getting Started`

### Development

1. Clone the repository:
   ```bash
   git clone https://github.com/0xAdiyat/Oto.git
   ```
2. Open in Xcode:
   ```bash
   open Oto.xcodeproj
   ```
3. Press **⌘R** to build and run. Oto appears in your menu bar — look for the icon in the top-right of your screen.

### Release Build (CLI)

```bash
./scripts/build-release.sh
```

Outputs to `dist/`:
- `dist/Oto.app` — ad-hoc signed app bundle
- `dist/Oto.zip` — portable zip (preserves codesigning)
- `dist/Oto.dmg` — drag-and-drop installer

Optionally install `xcbeautify` for prettier build output:
```bash
brew install xcbeautify
```

### Direct xcodebuild

```bash
# Debug
xcodebuild -project Oto.xcodeproj -scheme Oto -configuration Debug build

# Release
xcodebuild -project Oto.xcodeproj -scheme Oto -configuration Release build
```

> [!NOTE]
> **Requirements:** macOS 14 Sonoma or later · Xcode 15+ · No external dependencies

---

> [!IMPORTANT]
> ## Contributing
> If you'd like to contribute a new feature, trigger type, action, or bug fix, pull requests are welcome.
>
> - Branch naming: `feat/short-description`, `fix/short-description`, `refactor/short-description`
> - Keep UI changes scoped to `UI/`; keep audio logic scoped to `Auto/`
> - Any new design token belongs in `OtoTheme.swift` — no magic numbers in view files
> - Run a clean build (`xcodebuild clean build`) before opening a PR
>
> Send a [pull request](https://github.com/0xAdiyat/Oto/pulls) — I usually respond within 24–48 hours.

## `⚡️` `Activities`
![Alt](https://repobeats.axiom.co/api/embed/8cb4fb1e4728fa08724f4cac2198b71d53fe0946.svg "Repobeats analytics image")

---

## `🧑🏻‍💻` `Author`

@0xAdiyat

<br>
<p align="right">● <a href="#oto-top">back to top</a></p>
