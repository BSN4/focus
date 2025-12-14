//
//  WindowManager.swift
//  Focus
//
//  Accessibility API wrapper for window manipulation.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit
import ApplicationServices

// MARK: - Window Manager

final class WindowManager {
    // MARK: Singleton

    static let shared = WindowManager()
    private init() {}

    // MARK: Window Queries

    /// Returns the frontmost window for an application, if any.
    func getMainWindow(for app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return getWindows(for: appElement)?.first
    }

    /// Returns whether the application has any visible windows.
    func hasWindows(for app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = getWindows(for: appElement) else { return false }
        return !windows.isEmpty
    }

    /// Checks if a window is in fullscreen mode.
    func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        guard result == .success, let isFullscreen = value as? Bool else { return false }
        return isFullscreen
    }

    // MARK: Window Geometry

    /// Gets the current position of a window.
    func getPosition(of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        guard result == .success,
              CFGetTypeID(value) == AXValueGetTypeID(),
              let axValue = value else { return nil }

        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    /// Gets the current size of a window.
    func getSize(of window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard result == .success,
              CFGetTypeID(value) == AXValueGetTypeID(),
              let axValue = value else { return nil }

        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    /// Sets the position of a window.
    @discardableResult
    func setPosition(of window: AXUIElement, to position: CGPoint) -> Bool {
        var pos = position
        guard let value = AXValueCreate(.cgPoint, &pos) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    /// Sets the size of a window.
    @discardableResult
    func setSize(of window: AXUIElement, to size: CGSize) -> Bool {
        var windowSize = size
        guard let value = AXValueCreate(.cgSize, &windowSize) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }

    // MARK: Resize and Center

    /// Resizes and centers a window on the main screen.
    /// - Parameters:
    ///   - window: The window to manipulate
    ///   - size: Target size for the window
    ///   - centerOnly: If true, only centers without resizing
    func resizeAndCenter(_ window: AXUIElement, to size: CGSize, centerOnly: Bool = false) {
        guard let screen = NSScreen.main else { return }
        guard !isFullscreen(window) else { return }

        let visibleFrame = screen.visibleFrame

        // Determine final size
        let finalSize: CGSize
        if centerOnly {
            finalSize = getSize(of: window) ?? size
        } else {
            // Clamp to screen bounds
            finalSize = CGSize(
                width: min(size.width, visibleFrame.width),
                height: min(size.height, visibleFrame.height),
            )
            setSize(of: window, to: finalSize)
        }

        // Calculate centered position
        // Note: Accessibility API uses top-left origin coordinate system
        let menuBarHeight = screen.frame.height - visibleFrame.height - visibleFrame.origin.y + screen.frame.origin.y
        let centeredX = visibleFrame.origin.x + (visibleFrame.width - finalSize.width) / 2
        let centeredY = menuBarHeight + (visibleFrame.height - finalSize.height) / 2

        setPosition(of: window, to: CGPoint(x: centeredX, y: centeredY))
    }

    // MARK: Private Helpers

    private func getWindows(for appElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? [AXUIElement]
    }
}
