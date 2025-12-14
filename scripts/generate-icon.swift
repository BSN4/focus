#!/usr/bin/env swift

import AppKit
import CoreGraphics

func generateIcon(size: Int) -> Data? {
    let cgSize = CGFloat(size)
    let cornerRadius = cgSize * 0.223

    // Colors
    let backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
    let outerRectColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
    let innerRectColor = NSColor(red: 0.45, green: 0.45, blue: 0.95, alpha: 1.0)

    // Create bitmap with exact pixel dimensions (not points)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.current = context

    // Background with rounded corners
    let backgroundRect = CGRect(x: 0, y: 0, width: cgSize, height: cgSize)
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundColor.setFill()
    backgroundPath.fill()

    // Outer rectangle (window frame)
    let outerWidth = cgSize * 0.566
    let outerHeight = cgSize * 0.41
    let outerX = (cgSize - outerWidth) / 2
    let outerY = (cgSize - outerHeight) / 2
    let outerRect = CGRect(x: outerX, y: outerY, width: outerWidth, height: outerHeight)
    let outerCorner = cgSize * 0.023

    let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: outerCorner, yRadius: outerCorner)
    outerRectColor.setFill()
    outerPath.fill()

    // Inner rectangle (focused content)
    let innerWidth = cgSize * 0.312
    let innerHeight = cgSize * 0.215
    let innerX = (cgSize - innerWidth) / 2
    let innerY = (cgSize - innerHeight) / 2
    let innerRect = CGRect(x: innerX, y: innerY, width: innerWidth, height: innerHeight)
    let innerCorner = cgSize * 0.012

    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerCorner, yRadius: innerCorner)
    innerRectColor.setFill()
    innerPath.fill()

    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])
}

// Generate all required sizes
let basePath = "focus/Assets.xcassets/AppIcon.appiconset"

let sizes: [(Int, String)] = [
    (1024, "icon_1024.png"),
    (512, "icon_512.png"),
    (256, "icon_256.png"),
    (128, "icon_128.png"),
    (64, "icon_64.png"),
    (32, "icon_32.png"),
    (16, "icon_16.png")
]

for (size, filename) in sizes {
    if let pngData = generateIcon(size: size) {
        let path = "\(basePath)/\(filename)"
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            print("Saved \(size)x\(size): \(filename)")
        } catch {
            print("Failed to save \(filename): \(error)")
        }
    } else {
        print("Failed to generate \(filename)")
    }
}

print("Done!")
