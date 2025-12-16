//
//  ExcludedAppsController.swift
//  Focus
//
//  Manages the Excluded Apps submenu.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit

// MARK: - Excluded Apps Controller Delegate

protocol ExcludedAppsControllerDelegate: AnyObject {
    func excludedAppsDidChange(_ excludedApps: Set<String>)
    func currentExcludedApps() -> Set<String>
}

// MARK: - Excluded Apps Controller

final class ExcludedAppsController: NSObject {
    // MARK: Properties

    private weak var menu: NSMenu?
    weak var delegate: ExcludedAppsControllerDelegate?

    // MARK: Initialization

    init(menu: NSMenu) {
        self.menu = menu
        super.init()
    }

    // MARK: Menu Building

    func rebuildMenu() {
        guard let menu = menu else { return }
        menu.removeAllItems()

        let runningApps = getRunningApps()
        let excludedApps = delegate?.currentExcludedApps() ?? []

        if runningApps.isEmpty {
            addDisabledItem(to: menu, title: "No apps running")
            return
        }

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            let item = createMenuItem(for: app, bundleId: bundleId, isExcluded: excludedApps.contains(bundleId))
            menu.addItem(item)
        }

        if !excludedApps.isEmpty {
            menu.addItem(.separator())
            let clearItem = NSMenuItem(title: "Clear All Exclusions", action: #selector(clearAll), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }
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

    private func createMenuItem(for app: NSRunningApplication, bundleId: String, isExcluded: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: app.localizedName ?? bundleId,
            action: #selector(toggleExcludedApp(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = bundleId
        item.state = isExcluded ? .on : .off

        if let icon = app.icon {
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }

        return item
    }

    // MARK: Actions

    @objc private func toggleExcludedApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }

        var current = delegate?.currentExcludedApps() ?? []
        if current.contains(bundleId) {
            current.remove(bundleId)
        } else {
            current.insert(bundleId)
        }
        delegate?.excludedAppsDidChange(current)
    }

    @objc private func clearAll() {
        delegate?.excludedAppsDidChange([])
    }
}
