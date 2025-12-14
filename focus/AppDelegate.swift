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
    private var sizeMenuItems: [WindowSizePreset: NSMenuItem] = [:]

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

        // Enabled toggle
        enabledMenuItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        menu.addItem(.separator())

        // Window size submenu
        let sizeMenu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(
                title: preset.rawValue,
                action: #selector(selectSizePreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset
            sizeMenuItems[preset] = item
            sizeMenu.addItem(item)
        }

        let sizeMenuItem = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)

        // Center only toggle
        centerOnlyMenuItem = NSMenuItem(
            title: "Center Only",
            action: #selector(toggleCenterOnly),
            keyEquivalent: ""
        )
        centerOnlyMenuItem.target = self
        menu.addItem(centerOnlyMenuItem)

        menu.addItem(.separator())

        // Excluded apps submenu
        excludedAppsMenuItem = NSMenuItem(title: "Excluded Apps", action: nil, keyEquivalent: "")
        excludedAppsMenuItem.submenu = NSMenu()
        menu.addItem(excludedAppsMenuItem)

        menu.addItem(.separator())

        // Launch at login
        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Focus",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func updateMenuState() {
        enabledMenuItem?.state = isEnabled ? .on : .off
        centerOnlyMenuItem?.state = centerOnly ? .on : .off
        launchAtLoginMenuItem?.state = launchAtLogin ? .on : .off

        for (preset, item) in sizeMenuItems {
            item.state = preset == sizePreset ? .on : .off
        }
    }

    private func rebuildExcludedAppsMenu() {
        guard let submenu = excludedAppsMenuItem?.submenu else { return }
        submenu.removeAllItems()

        // Get running regular apps (excluding self)
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        if runningApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "No apps running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            submenu.addItem(noAppsItem)
            return
        }

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            let item = NSMenuItem(
                title: app.localizedName ?? bundleId,
                action: #selector(toggleExcludedApp(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = bundleId
            item.state = excludedApps.contains(bundleId) ? .on : .off

            // Add app icon if available
            if let icon = app.icon {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }

            submenu.addItem(item)
        }

        // Add separator and clear option if there are exclusions
        if !excludedApps.isEmpty {
            submenu.addItem(.separator())
            let clearItem = NSMenuItem(
                title: "Clear All Exclusions",
                action: #selector(clearExcludedApps),
                keyEquivalent: ""
            )
            clearItem.target = self
            submenu.addItem(clearItem)
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

    @objc private func toggleExcludedApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }

        var current = excludedApps
        if current.contains(bundleId) {
            current.remove(bundleId)
        } else {
            current.insert(bundleId)
        }
        excludedApps = current
    }

    @objc private func clearExcludedApps() {
        excludedApps = []
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Rebuild excluded apps menu when menu opens to show current running apps
        rebuildExcludedAppsMenu()
    }
}
