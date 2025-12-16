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

// MARK: - Shortcut Manager

final class ShortcutManager {
    // MARK: Singleton

    static let shared = ShortcutManager()

    // MARK: Properties

    private var shortcuts: [String: KeyCombo] = [:]
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // MARK: Callbacks

    var onShortcutTriggered: ((String) -> Void)?

    // MARK: Initialization

    private init() {}

    // MARK: Public API

    func start() {
        loadShortcuts()
        registerGlobalMonitor()
    }

    func stop() {
        unregisterMonitors()
    }

    func setShortcut(_ keyCombo: KeyCombo?, for bundleId: String) {
        if let keyCombo = keyCombo {
            // Remove any existing shortcut with the same key combo
            for (existingBundleId, existingCombo) in shortcuts {
                if existingCombo == keyCombo && existingBundleId != bundleId {
                    shortcuts.removeValue(forKey: existingBundleId)
                }
            }
            shortcuts[bundleId] = keyCombo
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
        shortcuts.removeAll()
        saveShortcuts()
    }

    func isKeyComboInUse(_ keyCombo: KeyCombo, excludingBundleId: String? = nil) -> String? {
        for (existingBundleId, existingCombo) in shortcuts {
            if existingCombo == keyCombo && existingBundleId != excludingBundleId {
                return existingBundleId
            }
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

    // MARK: Global Event Monitoring

    private func registerGlobalMonitor() {
        unregisterMonitors()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        print("[ShortcutManager] Global monitor registered")
    }

    private func unregisterMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let keyCombo = KeyCombo.from(event: event) else { return }

        guard let bundleId = shortcuts.first(where: { $0.value == keyCombo })?.key else { return }
        print("[ShortcutManager] Shortcut triggered for: \(bundleId)")
        activateApp(bundleId: bundleId)
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
