//
//  AppShortcutsController.swift
//  Focus
//
//  Manages the App Shortcuts submenu and shortcut recording.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit

// MARK: - App Shortcut Info

struct AppShortcutInfo {
    let bundleId: String
    let appName: String
    let appIcon: NSImage?
}

// MARK: - App Shortcuts Controller

final class AppShortcutsController: NSObject, ShortcutRecorderDelegate {
    // MARK: Properties

    private weak var menu: NSMenu?
    private var recorderController: ShortcutRecorderWindowController?

    // MARK: Initialization

    init(menu: NSMenu) {
        self.menu = menu
        super.init()
    }

    // MARK: Menu Building

    func rebuildMenu() {
        guard let menu = menu else { return }
        menu.removeAllItems()

        let shortcuts = ShortcutManager.shared.getAllShortcuts()
        let runningApps = getRunningApps()

        if runningApps.isEmpty {
            addDisabledItem(to: menu, title: "No apps running")
            return
        }

        addAppsWithShortcuts(to: menu, apps: runningApps, shortcuts: shortcuts)
        addAppsWithoutShortcuts(to: menu, apps: runningApps, shortcuts: shortcuts)
        addClearOption(to: menu, shortcuts: shortcuts)
    }

    // MARK: Private Helpers

    private func getRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func addDisabledItem(to menu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addAppsWithShortcuts(
        to menu: NSMenu,
        apps: [NSRunningApplication],
        shortcuts: [String: KeyCombo]
    ) {
        let appsWithShortcuts = apps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return shortcuts[bundleId] != nil
        }

        guard !appsWithShortcuts.isEmpty else { return }

        addDisabledItem(to: menu, title: "Shortcuts Assigned")

        for app in appsWithShortcuts {
            guard let bundleId = app.bundleIdentifier else { continue }
            let item = createMenuItem(for: app, bundleId: bundleId, shortcut: shortcuts[bundleId])
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    private func addAppsWithoutShortcuts(
        to menu: NSMenu,
        apps: [NSRunningApplication],
        shortcuts: [String: KeyCombo]
    ) {
        let appsWithoutShortcuts = apps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return true }
            return shortcuts[bundleId] == nil
        }

        guard !appsWithoutShortcuts.isEmpty else { return }

        addDisabledItem(to: menu, title: "Click to Set Shortcut")

        for app in appsWithoutShortcuts {
            guard let bundleId = app.bundleIdentifier else { continue }
            let item = createMenuItem(for: app, bundleId: bundleId, shortcut: nil)
            menu.addItem(item)
        }
    }

    private func addClearOption(to menu: NSMenu, shortcuts: [String: KeyCombo]) {
        guard !shortcuts.isEmpty else { return }

        menu.addItem(.separator())
        let clearItem = NSMenuItem(
            title: "Clear All Shortcuts",
            action: #selector(clearAllShortcuts),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
    }

    private func createMenuItem(
        for app: NSRunningApplication,
        bundleId: String,
        shortcut: KeyCombo?
    ) -> NSMenuItem {
        let title: String
        if let shortcut = shortcut {
            title = "\(app.localizedName ?? bundleId)  \(shortcut.displayString)"
        } else {
            title = app.localizedName ?? bundleId
        }

        let item = NSMenuItem(
            title: title,
            action: #selector(openShortcutRecorder(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = AppShortcutInfo(
            bundleId: bundleId,
            appName: app.localizedName ?? bundleId,
            appIcon: app.icon
        )

        if let icon = app.icon {
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }

        return item
    }

    // MARK: Actions

    @objc private func openShortcutRecorder(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? AppShortcutInfo else { return }

        let currentShortcut = ShortcutManager.shared.getShortcut(for: info.bundleId)

        recorderController = ShortcutRecorderWindowController(
            bundleId: info.bundleId,
            appName: info.appName,
            appIcon: info.appIcon,
            currentShortcut: currentShortcut
        )
        recorderController?.delegate = self
        recorderController?.showModal()
    }

    @objc private func clearAllShortcuts() {
        ShortcutManager.shared.clearAllShortcuts()
    }

    // MARK: ShortcutRecorderDelegate

    func shortcutRecorder(
        _ recorder: ShortcutRecorderWindowController,
        didRecordShortcut keyCombo: KeyCombo?,
        for bundleId: String
    ) {
        ShortcutManager.shared.setShortcut(keyCombo, for: bundleId)
        recorderController = nil
    }
}
