import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

/// User-recordable global hotkey. Persists to UserDefaults and registers with
/// Carbon's `RegisterEventHotKey` so it fires regardless of which app is
/// frontmost. Optional — by default no hotkey is set.
///
/// Why Carbon: It remains the only public API on macOS for system-wide
/// hotkeys without requiring Accessibility permission. The Carbon Events
/// shim is fully supported on Apple Silicon and is what every modern menu-
/// bar app (Raycast, Alfred, Things, etc.) uses under the hood.
@MainActor
@Observable
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    /// Currently assigned shortcut, or nil if disabled. Set via the recorder
    /// in Settings; persists across launches.
    private(set) var shortcut: HotkeyShortcut?

    /// Action invoked when the hotkey fires. Wired up at app launch to
    /// `SpotlightWindowController.shared.toggle()`.
    var onFire: (() -> Void)?

    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var eventHandler: EventHandlerRef?
    @ObservationIgnored private static var sharedSignature: OSType = {
        // Four-char code "Otoa" — must be a stable 4-byte FourCharCode.
        let chars: [UInt8] = [0x4F, 0x74, 0x6F, 0x61] // "Otoa"
        return chars.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()
    @ObservationIgnored private static let sharedHotkeyID: UInt32 = 1

    private static let storageKey = "Oto.globalHotkey.v1"

    private init() {
        shortcut = HotkeyShortcut.load(from: UserDefaults.standard, key: Self.storageKey)
        installEventHandler()
        if let s = shortcut { try? register(s) }
    }

    deinit {
        // EventHandlerRef + HotKeyRef cleanup must run on Carbon thread, but
        // these are safe to release from any context.
        if let h = eventHandler { RemoveEventHandler(h) }
        if let r = hotKeyRef { UnregisterEventHotKey(r) }
    }

    // MARK: - API

    /// Replace the current shortcut. Pass nil to disable.
    func update(_ new: HotkeyShortcut?) {
        // Always tear down the previous registration first. If the user is
        // changing key combos, registering the new one before unregistering
        // the old one would orphan a Carbon handle.
        if let r = hotKeyRef {
            UnregisterEventHotKey(r)
            hotKeyRef = nil
        }
        shortcut = new
        if let new {
            new.save(to: UserDefaults.standard, key: Self.storageKey)
            do {
                try register(new)
            } catch {
                // Registration can fail if another app already owns the
                // combo (e.g. ⌘Space taken by Spotlight). Surface to the
                // user by clearing — UI shows "tap to record" again.
                NSLog("Oto: hotkey register failed for \(new.displayString): \(error)")
                shortcut = nil
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    // MARK: - Internals

    enum HotkeyError: Error { case registerFailed(OSStatus) }

    private func register(_ shortcut: HotkeyShortcut) throws {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.sharedSignature, id: Self.sharedHotkeyID)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            UInt32(shortcut.carbonModifierFlags),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            throw HotkeyError.registerFailed(status)
        }
        hotKeyRef = ref
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // We pass a raw pointer to `self` so the C callback can route back to
        // the right instance. `self` is a singleton, so the unmanaged retain
        // is intentional and lifetime-safe (manager lives for app lifetime).
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr,
                      hkID.signature == GlobalHotkeyManager.sharedSignature,
                      hkID.id == GlobalHotkeyManager.sharedHotkeyID else {
                    return OSStatus(eventNotHandledErr)
                }
                Task { @MainActor in manager.onFire?() }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
        eventHandler = handlerRef
    }
}

// MARK: - HotkeyShortcut

/// Codable description of a key + modifier flags combo.
struct HotkeyShortcut: Codable, Hashable {
    /// Carbon virtual keyCode (e.g. `kVK_ANSI_O` = 31).
    let keyCode: UInt16
    /// Cocoa modifier-flag bitmask (`NSEvent.ModifierFlags.rawValue`). Stored
    /// in Cocoa form so the recorder, display, and persistence layers all
    /// agree; the Carbon equivalent is computed for registration.
    let cocoaModifierFlags: UInt

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: cocoaModifierFlags)
    }

    /// Carbon hotkey modifier flags — `cmdKey | optionKey | …`.
    var carbonModifierFlags: Int {
        var carbon = 0
        let flags = modifierFlags
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option)  { carbon |= optionKey }
        if flags.contains(.shift)   { carbon |= shiftKey }
        if flags.contains(.control) { carbon |= controlKey }
        return carbon
    }

    /// Pretty-printed combo, e.g. "⌃⌥⌘O".
    var displayString: String {
        var s = ""
        let flags = modifierFlags
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    /// Reject combos that have no modifier (would clobber typing) or that
    /// are pure modifiers (no actual key). The recorder enforces this before
    /// constructing a shortcut, but validate again here as a backstop.
    var isValid: Bool {
        let mods: NSEvent.ModifierFlags = [.command, .option, .control]
        return modifierFlags.intersection(mods).isEmpty == false
    }

    static func load(from defaults: UserDefaults, key: String) -> HotkeyShortcut? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(HotkeyShortcut.self, from: data),
              decoded.isValid else { return nil }
        return decoded
    }

    func save(to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: key)
        }
    }

    static func keyName(for code: UInt16) -> String {
        // Common keys we want pretty names for. For everything else, look up
        // the layout-aware character via `UCKeyTranslate`.
        if let special = specialKeys[code] { return special }
        return Self.layoutKeyName(for: code) ?? "Key \(code)"
    }

    private static let specialKeys: [UInt16: String] = [
        UInt16(kVK_Space):       "Space",
        UInt16(kVK_Return):      "↩",
        UInt16(kVK_Tab):         "⇥",
        UInt16(kVK_Escape):      "⎋",
        UInt16(kVK_Delete):      "⌫",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_LeftArrow):   "←",
        UInt16(kVK_RightArrow):  "→",
        UInt16(kVK_UpArrow):     "↑",
        UInt16(kVK_DownArrow):   "↓",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]

    /// Translate a virtual key code to its character on the user's current
    /// keyboard layout. Returns uppercased single-character string or nil.
    private static func layoutKeyName(for code: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let layoutBytes = CFDataGetBytePtr(dataRef)
        let layout = unsafeBitCast(layoutBytes, to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength = 0
        let status = UCKeyTranslate(
            layout,
            code,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &realLength,
            &chars
        )
        guard status == noErr, realLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: realLength).uppercased()
    }
}

// MARK: - Recorder view

/// Click-to-record control. While recording, captures the next key-down with
/// any modifier and returns a `HotkeyShortcut`. Pressing Escape cancels;
/// pressing Delete with no modifier clears the existing shortcut.
struct HotkeyRecorder: View {
    @Binding var shortcut: HotkeyShortcut?
    var onCommit: (HotkeyShortcut?) -> Void = { _ in }

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(minWidth: 110)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isRecording ? Color.otoTeal.opacity(0.18) : OtoUI.rowIdle,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isRecording ? Color.otoTeal.opacity(0.5) : OtoUI.dividerColor,
                                lineWidth: 1
                            )
                    }
                    .foregroundStyle(isRecording ? Color.otoTeal : .primary)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            if shortcut != nil && !isRecording {
                Button {
                    shortcut = nil
                    onCommit(nil)
                } label: {
                    OtoIcon(name: "xmark", size: 11)
                        .foregroundStyle(OtoUI.mutedFG)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if isRecording { return "Press a combo…" }
        if let s = shortcut { return s.displayString }
        return "Click to record"
    }

    private func startRecording() {
        // Tear down any previous monitor first — calling startRecording twice
        // in a row (e.g. user clicks the button while it's active) shouldn't
        // stack monitors.
        stopRecording()
        isRecording = true
        // Local monitor: only fires while our window is key. That's exactly
        // right — we don't want to capture system-wide keystrokes during
        // recording.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        // Escape cancels recording without changing anything.
        if event.type == .keyDown && event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return nil
        }

        // Delete-with-no-modifier clears the shortcut.
        if event.type == .keyDown
            && event.keyCode == UInt16(kVK_Delete)
            && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            shortcut = nil
            onCommit(nil)
            stopRecording()
            return nil
        }

        guard event.type == .keyDown else { return event }

        // Require at least one of cmd/opt/ctrl. Plain shift+letter would
        // hijack normal typing and is intentionally rejected — we surface
        // a brief flash by ignoring the event but keeping recording on.
        let requiredMods: NSEvent.ModifierFlags = [.command, .option, .control]
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard mods.intersection(requiredMods).isEmpty == false else {
            NSSound.beep()
            return nil
        }

        let new = HotkeyShortcut(keyCode: event.keyCode, cocoaModifierFlags: mods.rawValue)
        shortcut = new
        onCommit(new)
        stopRecording()
        return nil
    }
}
