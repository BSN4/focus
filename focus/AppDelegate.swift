//
//  AppDelegate.swift
//  Focus
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit
import ServiceManagement

// MARK: - Window Size Presets

enum WindowSizePreset: String, CaseIterable {
    case small = "Small (1200×800)"
    case medium = "Medium (1400×900)"
    case large = "Large (1600×1000)"

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 1200, height: 800)
        case .medium: CGSize(width: 1400, height: 900)
        case .large: CGSize(width: 1600, height: 1000)
        }
    }
}

// MARK: - UserDefaults Keys

private enum DefaultsKey {
    static let isEnabled = "isEnabled"
    static let centerOnly = "centerOnly"
    static let sizePreset = "sizePreset"
    static let excludedApps = "excludedApps"
    static let appShortcuts = "appShortcuts"
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: Properties

    private var statusItem: NSStatusItem!
    private var focusManager: FocusManager!

    private var enabledMenuItem: NSMenuItem!
    private var centerOnlyMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var excludedAppsMenuItem: NSMenuItem!
    private var appShortcutsMenuItem: NSMenuItem!
    private var sizeMenuItems: [WindowSizePreset: NSMenuItem] = [:]
    private var appShortcutsController: AppShortcutsController?
    private var excludedAppsController: ExcludedAppsController?

    // MARK: Persisted Settings

    private var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.isEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.isEnabled)
            focusManager.isEnabled = newValue
            updateMenuState()
        }
    }

    private var centerOnly: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.centerOnly) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.centerOnly)
            focusManager.centerOnly = newValue
            updateMenuState()
        }
    }

    private var sizePreset: WindowSizePreset {
        get {
            let raw = UserDefaults.standard.string(forKey: DefaultsKey.sizePreset)
            return raw.flatMap(WindowSizePreset.init) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.sizePreset)
            focusManager.windowSize = newValue.size
            updateMenuState()
        }
    }

    private var excludedApps: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: DefaultsKey.excludedApps) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: DefaultsKey.excludedApps)
            focusManager.excludedApps = newValue
        }
    }

    private var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
            updateMenuState()
        }
    }

    // MARK: App Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        registerDefaults()
        setupStatusItem()
        setupFocusManager()
        setupShortcutManager()
        requestAccessibilityPermission()
    }

    // MARK: Setup

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            DefaultsKey.isEnabled: true,
            DefaultsKey.centerOnly: false,
            DefaultsKey.sizePreset: WindowSizePreset.medium.rawValue,
            DefaultsKey.excludedApps: [String]()
        ])
    }

    private func setupFocusManager() {
        focusManager = FocusManager()
        focusManager.isEnabled = isEnabled
        focusManager.centerOnly = centerOnly
        focusManager.windowSize = sizePreset.size
        focusManager.excludedApps = excludedApps
        focusManager.start()
    }

    private func setupShortcutManager() {
        ShortcutManager.shared.start()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton()
        statusItem.menu = buildMenu()
        updateMenuState()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        if let image = NSImage(
            systemSymbolName: "rectangle.center.inset.filled",
            accessibilityDescription: "Focus"
        ) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "F"
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        addEnabledToggle(to: menu)
        menu.addItem(.separator())
        addWindowSizeSubmenu(to: menu)
        addCenterOnlyToggle(to: menu)
        menu.addItem(.separator())
        addExcludedAppsSubmenu(to: menu)
        addAppShortcutsSubmenu(to: menu)
        menu.addItem(.separator())
        addLaunchAtLoginToggle(to: menu)
        menu.addItem(.separator())
        addQuitItem(to: menu)

        return menu
    }

    private func addEnabledToggle(to menu: NSMenu) {
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)
    }

    private func addWindowSizeSubmenu(to menu: NSMenu) {
        let sizeMenu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(selectSizePreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            sizeMenuItems[preset] = item
            sizeMenu.addItem(item)
        }
        let sizeMenuItem = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)
    }

    private func addCenterOnlyToggle(to menu: NSMenu) {
        centerOnlyMenuItem = NSMenuItem(title: "Center Only", action: #selector(toggleCenterOnly), keyEquivalent: "")
        centerOnlyMenuItem.target = self
        menu.addItem(centerOnlyMenuItem)
    }

    private func addExcludedAppsSubmenu(to menu: NSMenu) {
        excludedAppsMenuItem = NSMenuItem(title: "Excluded Apps", action: nil, keyEquivalent: "")
        let excludedSubmenu = NSMenu()
        excludedAppsMenuItem.submenu = excludedSubmenu
        excludedAppsController = ExcludedAppsController(menu: excludedSubmenu)
        excludedAppsController?.delegate = self
        menu.addItem(excludedAppsMenuItem)
    }

    private func addAppShortcutsSubmenu(to menu: NSMenu) {
        appShortcutsMenuItem = NSMenuItem(title: "App Shortcuts", action: nil, keyEquivalent: "")
        let shortcutsSubmenu = NSMenu()
        appShortcutsMenuItem.submenu = shortcutsSubmenu
        appShortcutsController = AppShortcutsController(menu: shortcutsSubmenu)
        menu.addItem(appShortcutsMenuItem)
    }

    private func addLaunchAtLoginToggle(to menu: NSMenu) {
        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)
    }

    private func addQuitItem(to menu: NSMenu) {
        let quitItem = NSMenuItem(title: "Quit Focus", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateMenuState() {
        enabledMenuItem?.state = isEnabled ? .on : .off
        centerOnlyMenuItem?.state = centerOnly ? .on : .off
        launchAtLoginMenuItem?.state = launchAtLogin ? .on : .off

        for (preset, item) in sizeMenuItems {
            item.state = preset == sizePreset ? .on : .off
        }
    }

    // MARK: Permissions

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Focus needs Accessibility permission to resize and move windows.

        Please grant permission in System Settings → Privacy & Security → Accessibility, \
        then restart the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
    }

    @objc private func toggleCenterOnly() {
        centerOnly.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }

    @objc private func selectSizePreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowSizePreset else { return }
        sizePreset = preset
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        excludedAppsController?.rebuildMenu()
        appShortcutsController?.rebuildMenu()
    }
}

// MARK: - ExcludedAppsControllerDelegate

extension AppDelegate: ExcludedAppsControllerDelegate {
    func excludedAppsDidChange(_ newExcludedApps: Set<String>) {
        excludedApps = newExcludedApps
    }

    func currentExcludedApps() -> Set<String> {
        excludedApps
    }
}
