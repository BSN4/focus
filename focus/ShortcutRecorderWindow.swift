//
//  ShortcutRecorderWindow.swift
//  Focus
//
//  A window for recording keyboard shortcuts for apps.
//
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//  MIT License
//

import AppKit
import Carbon.HIToolbox

// MARK: - Shortcut Recorder Delegate

protocol ShortcutRecorderDelegate: AnyObject {
    func shortcutRecorder(
        _ recorder: ShortcutRecorderWindowController,
        didRecordShortcut keyCombo: KeyCombo?,
        for bundleId: String
    )
}

// MARK: - Shortcut Recorder Window Controller

final class ShortcutRecorderWindowController: NSWindowController {
    // MARK: Properties

    weak var delegate: ShortcutRecorderDelegate?

    private let bundleId: String
    private let appName: String
    private let appIcon: NSImage?
    private var currentShortcut: KeyCombo?

    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var instructionLabel: NSTextField!
    private var shortcutField: ShortcutRecorderField!
    private var clearButton: NSButton!
    private var cancelButton: NSButton!
    private var saveButton: NSButton!
    private var conflictLabel: NSTextField!

    // MARK: Initialization

    init(bundleId: String, appName: String, appIcon: NSImage?, currentShortcut: KeyCombo?) {
        self.bundleId = bundleId
        self.appName = appName
        self.appIcon = appIcon
        self.currentShortcut = currentShortcut

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Shortcut"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        setupUI()
        updateUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        setupHeaderViews(in: contentView)
        setupShortcutControls(in: contentView)
        setupActionButtons(in: contentView)
    }

    private func setupHeaderViews(in contentView: NSView) {
        iconView = NSImageView(frame: NSRect(x: 20, y: 160, width: 40, height: 40))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = appIcon
        contentView.addSubview(iconView)

        titleLabel = createLabel(
            text: appName,
            frame: NSRect(x: 70, y: 168, width: 290, height: 24),
            font: .boldSystemFont(ofSize: 16)
        )
        contentView.addSubview(titleLabel)

        let instruction = "Press a shortcut key combination to switch to this app.\n"
            + "Use ⌘, ⌥, ⌃ with a letter or number key."
        instructionLabel = createLabel(
            text: instruction,
            frame: NSRect(x: 20, y: 115, width: 340, height: 40),
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        contentView.addSubview(instructionLabel)
    }

    private func setupShortcutControls(in contentView: NSView) {
        shortcutField = ShortcutRecorderField(frame: NSRect(x: 20, y: 75, width: 260, height: 30))
        shortcutField.keyCombo = currentShortcut
        shortcutField.onKeyComboChanged = { [weak self] in self?.handleShortcutChanged($0) }
        contentView.addSubview(shortcutField)

        clearButton = createButton(title: "Clear", frame: NSRect(x: 290, y: 75, width: 70, height: 30))
        clearButton.action = #selector(clearShortcut)
        contentView.addSubview(clearButton)

        conflictLabel = createLabel(
            text: "",
            frame: NSRect(x: 20, y: 50, width: 340, height: 20),
            font: .systemFont(ofSize: 11),
            color: .systemRed
        )
        contentView.addSubview(conflictLabel)
    }

    private func setupActionButtons(in contentView: NSView) {
        cancelButton = createButton(title: "Cancel", frame: NSRect(x: 190, y: 12, width: 85, height: 30))
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1B}"
        contentView.addSubview(cancelButton)

        saveButton = createButton(title: "Save", frame: NSRect(x: 280, y: 12, width: 85, height: 30))
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
    }

    private func createButton(title: String, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        return button
    }

    private func createLabel(text: String, frame: NSRect, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = font
        label.textColor = color
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byWordWrapping
        return label
    }

    // MARK: UI Updates

    private func updateUI() {
        clearButton.isEnabled = shortcutField.keyCombo != nil
    }

    private func handleShortcutChanged(_ keyCombo: KeyCombo?) {
        guard let keyCombo = keyCombo else {
            conflictLabel.stringValue = ""
            updateUI()
            return
        }

        // Check for conflicts
        if let conflictBundleId = ShortcutManager.shared.isKeyComboInUse(keyCombo, excludingBundleId: bundleId) {
            let conflictAppName = getAppName(for: conflictBundleId)
            conflictLabel.stringValue = "⚠️ Already used by \(conflictAppName)"
        } else {
            conflictLabel.stringValue = ""
        }

        updateUI()
    }

    private func getAppName(for bundleId: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleId }?
            .localizedName ?? bundleId
    }

    // MARK: Actions

    @objc private func clearShortcut() {
        shortcutField.keyCombo = nil
        conflictLabel.stringValue = ""
        updateUI()
    }

    @objc private func cancel() {
        window?.close()
        NSApp.stopModal()
    }

    @objc private func save() {
        delegate?.shortcutRecorder(self, didRecordShortcut: shortcutField.keyCombo, for: bundleId)
        window?.close()
        NSApp.stopModal()
    }

    // MARK: Presentation

    func showModal() {
        guard let window = window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(shortcutField)
        NSApp.runModal(for: window)
    }
}

// MARK: - Shortcut Recorder Field

final class ShortcutRecorderField: NSView {
    // MARK: Properties

    var keyCombo: KeyCombo? {
        didSet { updateDisplay() }
    }

    var onKeyComboChanged: ((KeyCombo?) -> Void)?

    private var displayLabel: NSTextField!
    private var isRecording = false

    // MARK: Initialization

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UI Setup

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()

        displayLabel = NSTextField(frame: bounds.insetBy(dx: 10, dy: 5))
        displayLabel.autoresizingMask = [.width, .height]
        displayLabel.isBezeled = false
        displayLabel.drawsBackground = false
        displayLabel.isEditable = false
        displayLabel.isSelectable = false
        displayLabel.alignment = .center
        displayLabel.font = .systemFont(ofSize: 14)
        addSubview(displayLabel)

        updateDisplay()
    }

    private func updateAppearance() {
        if isRecording {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    private func updateDisplay() {
        if isRecording {
            displayLabel.stringValue = "Press shortcut..."
            displayLabel.textColor = .secondaryLabelColor
        } else if let keyCombo = keyCombo {
            displayLabel.stringValue = keyCombo.displayString
            displayLabel.textColor = .labelColor
        } else {
            displayLabel.stringValue = "Click to record shortcut"
            displayLabel.textColor = .tertiaryLabelColor
        }
    }

    // MARK: First Responder

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        updateAppearance()
        updateDisplay()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateAppearance()
        updateDisplay()
        return super.resignFirstResponder()
    }

    // MARK: Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    // MARK: Keyboard Events

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape clears and exits recording
        if event.keyCode == UInt16(kVK_Escape) {
            keyCombo = nil
            onKeyComboChanged?(nil)
            window?.makeFirstResponder(nil)
            return
        }

        // Try to create a valid key combo
        if let newCombo = KeyCombo.from(event: event) {
            keyCombo = newCombo
            onKeyComboChanged?(newCombo)
            isRecording = false
            updateAppearance()
            updateDisplay()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Visual feedback when modifiers are pressed during recording
        if isRecording {
            needsDisplay = true
        }
    }
}
