//
//  ShortcutManager.swift
//  Focus
//
//  Manages global keyboard shortcuts for switching to specific apps.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit
import Carbon.HIToolbox

// MARK: - Key Combo

struct KeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt

    // MARK: Modifier Flags

    var hasCommand: Bool { modifiers & NSEvent.ModifierFlags.command.rawValue != 0 }
    var hasOption: Bool { modifiers & NSEvent.ModifierFlags.option.rawValue != 0 }
    var hasControl: Bool { modifiers & NSEvent.ModifierFlags.control.rawValue != 0 }
    var hasShift: Bool { modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 }

    // MARK: Display String

    var displayString: String {
        var parts: [String] = []

        if hasControl { parts.append("⌃") }
        if hasOption { parts.append("⌥") }
        if hasShift { parts.append("⇧") }
        if hasCommand { parts.append("⌘") }

        if let keyString = KeyCombo.keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    // MARK: Validation

    var isValid: Bool {
        // Must have at least one modifier (Command, Option, or Control)
        let hasModifier = hasCommand || hasOption || hasControl
        return hasModifier && keyCode != 0
    }

    // MARK: Key Code Mapping

    private static let keyCodeMap: [Int: String] = {
        let mappings: [(Int, String)] = [
            // Letters
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"),
            (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"),
            (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"), (kVK_ANSI_P, "P"),
            (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z"),
            // Numbers
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"),
            (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9"),
            // Function keys
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"),
            (kVK_F5, "F5"), (kVK_F6, "F6"), (kVK_F7, "F7"), (kVK_F8, "F8"),
            (kVK_F9, "F9"), (kVK_F10, "F10"), (kVK_F11, "F11"), (kVK_F12, "F12"),
            // Special keys
            (kVK_Space, "Space"), (kVK_Return, "↩"), (kVK_Tab, "⇥"),
            (kVK_Delete, "⌫"), (kVK_ForwardDelete, "⌦"), (kVK_Escape, "⎋"),
            (kVK_LeftArrow, "←"), (kVK_RightArrow, "→"),
            (kVK_UpArrow, "↑"), (kVK_DownArrow, "↓"),
            (kVK_Home, "↖"), (kVK_End, "↘"), (kVK_PageUp, "⇞"), (kVK_PageDown, "⇟"),
            // Punctuation
            (kVK_ANSI_Minus, "-"), (kVK_ANSI_Equal, "="),
            (kVK_ANSI_LeftBracket, "["), (kVK_ANSI_RightBracket, "]"),
            (kVK_ANSI_Semicolon, ";"), (kVK_ANSI_Quote, "'"),
            (kVK_ANSI_Comma, ","), (kVK_ANSI_Period, "."),
            (kVK_ANSI_Slash, "/"), (kVK_ANSI_Backslash, "\\"), (kVK_ANSI_Grave, "`")
        ]
        return Dictionary(uniqueKeysWithValues: mappings)
    }()

    private static func keyCodeToString(_ keyCode: UInt16) -> String? {
        keyCodeMap[Int(keyCode)]
    }

    // MARK: Factory

    static func from(event: NSEvent) -> KeyCombo? {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue

        let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        return combo.isValid ? combo : nil
    }
}

// MARK: - App Shortcut

struct AppShortcut: Codable {
    let bundleIdentifier: String
    let keyCombo: KeyCombo
}

// MARK: - Hotkey ID

private struct HotkeyID {
    let signature: OSType
    let id: UInt32
}

// MARK: - Shortcut Manager

final class ShortcutManager {
    // MARK: Singleton

    static let shared = ShortcutManager()

    // MARK: Properties

    private var shortcuts: [String: KeyCombo] = [:]
    private var hotkeyRefs: [String: EventHotKeyRef] = [:]
    private var hotkeyIdToBundle: [UInt32: String] = [:]
    private var nextHotkeyId: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    // MARK: Callbacks

    var onShortcutTriggered: ((String) -> Void)?

    // MARK: Initialization

    private init() {
        installEventHandler()
    }

    deinit {
        unregisterAllHotkeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    // MARK: Public API

    func start() {
        loadShortcuts()
        registerAllHotkeys()
    }

    func stop() {
        unregisterAllHotkeys()
    }

    func setShortcut(_ keyCombo: KeyCombo?, for bundleId: String) {
        // Unregister old hotkey if exists
        unregisterHotkey(for: bundleId)

        if let keyCombo = keyCombo {
            // Remove any existing shortcut with the same key combo
            for (existingBundleId, existingCombo) in shortcuts {
                guard existingCombo == keyCombo && existingBundleId != bundleId else { continue }
                unregisterHotkey(for: existingBundleId)
                shortcuts.removeValue(forKey: existingBundleId)
            }
            shortcuts[bundleId] = keyCombo
            registerHotkey(for: bundleId, keyCombo: keyCombo)
        } else {
            shortcuts.removeValue(forKey: bundleId)
        }
        saveShortcuts()
    }

    func getShortcut(for bundleId: String) -> KeyCombo? {
        shortcuts[bundleId]
    }

    func getAllShortcuts() -> [String: KeyCombo] {
        shortcuts
    }

    func clearAllShortcuts() {
        unregisterAllHotkeys()
        shortcuts.removeAll()
        saveShortcuts()
    }

    func isKeyComboInUse(_ keyCombo: KeyCombo, excludingBundleId: String? = nil) -> String? {
        for (existingBundleId, existingCombo) in shortcuts {
            guard existingCombo == keyCombo && existingBundleId != excludingBundleId else { continue }
            return existingBundleId
        }
        return nil
    }

    // MARK: Persistence

    private static let shortcutsKey = "appShortcuts"

    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: Self.shortcutsKey),
              let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data)
        else {
            shortcuts = [:]
            return
        }
        shortcuts = decoded
        print("[ShortcutManager] Loaded \(shortcuts.count) shortcuts")
    }

    private func saveShortcuts() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.shortcutsKey)
        print("[ShortcutManager] Saved \(shortcuts.count) shortcuts")
    }

    // MARK: Carbon Hotkey Registration

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotkeyEvent(event)
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, selfPtr, &eventHandler)
        print("[ShortcutManager] Carbon event handler installed")
    }

    private func registerAllHotkeys() {
        for (bundleId, keyCombo) in shortcuts {
            registerHotkey(for: bundleId, keyCombo: keyCombo)
        }
    }

    private func registerHotkey(for bundleId: String, keyCombo: KeyCombo) {
        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var hotKeyID = EventHotKeyID(signature: OSType(0x464F4355), id: hotkeyId) // 'FOCU'
        var hotKeyRef: EventHotKeyRef?

        let modifiers = carbonModifiers(from: keyCombo)
        let status = RegisterEventHotKey(
            UInt32(keyCombo.keyCode),
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs[bundleId] = ref
            hotkeyIdToBundle[hotkeyId] = bundleId
            print("[ShortcutManager] Registered hotkey \(keyCombo.displayString) for \(bundleId)")
        } else {
            print("[ShortcutManager] Failed to register hotkey: \(status)")
        }
    }

    private func unregisterHotkey(for bundleId: String) {
        guard let ref = hotkeyRefs[bundleId] else { return }
        UnregisterEventHotKey(ref)
        hotkeyRefs.removeValue(forKey: bundleId)
        hotkeyIdToBundle = hotkeyIdToBundle.filter { $0.value != bundleId }
        print("[ShortcutManager] Unregistered hotkey for \(bundleId)")
    }

    private func unregisterAllHotkeys() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        hotkeyIdToBundle.removeAll()
    }

    private func carbonModifiers(from keyCombo: KeyCombo) -> UInt32 {
        var modifiers: UInt32 = 0
        if keyCombo.hasCommand { modifiers |= UInt32(cmdKey) }
        if keyCombo.hasOption { modifiers |= UInt32(optionKey) }
        if keyCombo.hasControl { modifiers |= UInt32(controlKey) }
        if keyCombo.hasShift { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private func handleHotkeyEvent(_ event: EventRef?) {
        guard let event = event else { return }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return }
        guard let bundleId = hotkeyIdToBundle[hotKeyID.id] else { return }

        print("[ShortcutManager] Hotkey triggered for: \(bundleId)")
        DispatchQueue.main.async {
            self.activateApp(bundleId: bundleId)
        }
    }

    // MARK: App Activation

    private func activateApp(bundleId: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleId
        }) else {
            // App not running, try to launch it
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error = error {
                        print("[ShortcutManager] Failed to launch app: \(error)")
                    }
                }
            }
            return
        }

        app.activate(options: [.activateIgnoringOtherApps])
        onShortcutTriggered?(bundleId)
    }
}
