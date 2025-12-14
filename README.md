# Focus

A lightweight macOS menu bar app that enforces single-app focus. When you switch apps, everything else hides automatically.

## The Problem

macOS Tahoe ships with window management that looks good on paper but fails keyboard-driven users in practice:

- Multiple virtual desktops sound efficient but each Space maintains its own window buffer. 4+ Spaces = unnecessary GPU/memory overhead for context you're not even looking at.

## The Philosophy

The cleanest workflow isn't about managing multiple visible windows. It's about **only seeing what you're working on**.

> One app. Centered. Everything else gone.

No tiling. No Spaces. No window arrangements to maintain. Switch apps, and the view resets automatically.

This approach Uses single desktop = minimal GPU compositing

## How It Works

Focus runs as a menu bar daemon (~5MB memory) and listens for one thing: **app activation**.

When you switch to any app:
1. All other apps hide instantly (`NSRunningApplication.hide()`)
2. The frontmost window resizes to your preferred dimensions
3. The window centers on screen

## Menu Bar Options

- **Enabled** — Toggle on/off without quitting
- **Window Size** — Small (1200×800) / Medium (1400×900) / Large (1600×1000)
- **Center Only** — Disable resize, just center windows
- **Quit**

## Build

```bash
# Clone and build
git clone https://github.com/BSN4/focus.git
cd focus
make release

# Install to /Applications
make install
```

Or open `focus.xcodeproj` in Xcode and build (Cmd+B).

Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility).

## Why Not Just Use ⌘ + ⌥ + H?

Focus automates the discipline.

## Author

Bader <BNS4@pm.me>

## License

MIT
