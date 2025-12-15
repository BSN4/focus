//
//  FocusManager.swift
//  Focus
//
//  Core logic for hiding apps and managing window focus.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit

// MARK: - Focus Manager

final class FocusManager {
    // MARK: Configuration

    var isEnabled: Bool = true
    var centerOnly: Bool = false
    var windowSize: CGSize = .init(width: 1400, height: 900)

    /// Bundle identifiers of apps that should not trigger focus mode
    /// (other apps won't hide when switching to these)
    var excludedApps: Set<String> = []

    // MARK: Private Properties

    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.1
    private let windowManager = WindowManager.shared

    // MARK: Lifecycle

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    deinit {
        stop()
    }

    // MARK: App Activation Handler

    @objc private func handleAppActivation(_ notification: Notification) {
        print("[Focus] App activation detected")
        guard isEnabled else {
            print("[Focus] Disabled, skipping")
            return
        }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            print("[Focus] Could not get app from notification")
            return
        }

        print("[Focus] Activated: \(app.localizedName ?? "unknown")")

        guard shouldProcessApp(app) else {
            print("[Focus] App filtered out by shouldProcessApp")
            return
        }

        print("[Focus] Processing app switch...")
        debounceAndProcess(app)
    }

    // MARK: App Filtering

    private func shouldProcessApp(_ app: NSRunningApplication) -> Bool {
        // Ignore self
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("[Focus] Filtered: is self")
            return false
        }

        // Ignore non-regular apps (SecurityAgent, Spotlight, system dialogs, menu bar apps)
        if app.activationPolicy != .regular {
            print("[Focus] Filtered: not a regular app (policy: \(app.activationPolicy.rawValue))")
            return false
        }

        // Ignore excluded apps
        if let bundleId = app.bundleIdentifier, excludedApps.contains(bundleId) {
            print("[Focus] Filtered: excluded app")
            return false
        }

        let hasWindows = windowManager.hasWindows(for: app)
        print("[Focus] hasWindows for \(app.localizedName ?? "?"): \(hasWindows)")

        // Ignore Finder desktop (Finder with no windows = desktop click)
        if app.bundleIdentifier == "com.apple.finder", !hasWindows {
            print("[Focus] Filtered: Finder desktop")
            return false
        }

        // Ignore menu bar apps and apps without windows
        if !hasWindows {
            print("[Focus] Filtered: no windows")
            return false
        }

        return true
    }

    // MARK: Debounced Processing

    private func debounceAndProcess(_ app: NSRunningApplication) {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.processAppSwitch(app)
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    private func processAppSwitch(_ app: NSRunningApplication) {
        hideOtherApps(except: app)
        resizeAndCenterWindow(for: app)
    }

    // MARK: Hide Other Apps

    private func hideOtherApps(except activeApp: NSRunningApplication) {
        for app in NSWorkspace.shared.runningApplications {
            guard shouldHideApp(app, activeApp: activeApp) else { continue }
            let result = app.hide()
            print("[Focus] Hiding \(app.localizedName ?? "unknown"): \(result ? "success" : "FAILED")")
        }
    }

    private func shouldHideApp(_ app: NSRunningApplication, activeApp: NSRunningApplication) -> Bool {
        // Don't hide the active app
        if app.processIdentifier == activeApp.processIdentifier {
            return false
        }

        // Already hidden
        if app.isHidden {
            return false
        }

        // Only hide regular apps (not background processes or accessories)
        if app.activationPolicy != .regular {
            return false
        }

        // Don't hide self
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return true
    }

    // MARK: Window Management

    private func resizeAndCenterWindow(for app: NSRunningApplication) {
        guard let window = windowManager.getMainWindow(for: app) else { return }
        windowManager.resizeAndCenter(window, to: windowSize, centerOnly: centerOnly)
    }
}
