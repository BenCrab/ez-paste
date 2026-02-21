#!/usr/bin/env swift

import AppKit
import Foundation

let _ = NSApplication.shared

// Resolve paths relative to this script
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path
let svgPath   = "\(scriptDir)/Resources/ez-paste.svg"
let iconsetDir = "\(scriptDir)/Resources/ez-paste.iconset"
let icnsPath   = "\(scriptDir)/Resources/ez-paste.icns"

guard let svgImage = NSImage(contentsOfFile: svgPath) else {
    print("❌ Failed to load SVG: \(svgPath)")
    exit(1)
}
print("✓ Loaded SVG (\(Int(svgImage.size.width))×\(Int(svgImage.size.height)))")

try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // macOS 26 rounded-rect background — ~22.4% corner radius
    let r = s * 0.224
    let bounds = NSRect(x: 0, y: 0, width: s, height: s)
    let path = NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r)
    NSColor.white.setFill()
    path.fill()

    // Centre the logo with 15% padding, preserving aspect ratio
    let pad = s * 0.15
    let available = NSRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let aspect = svgImage.size.width / svgImage.size.height
    var drawRect = available
    if aspect > 1 {
        let h = available.width / aspect
        drawRect.origin.y  = available.minY + (available.height - h) / 2
        drawRect.size.height = h
    } else {
        let w = available.height * aspect
        drawRect.origin.x  = available.minX + (available.width - w) / 2
        drawRect.size.width = w
    }

    svgImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

// All sizes required by macOS iconset
let iconset: [(size: Int, name: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

var cache = [Int: Data]()
for (size, name) in iconset {
    if cache[size] == nil {
        guard let data = renderIcon(size: size) else {
            print("❌ Failed to render \(size)px"); exit(1)
        }
        cache[size] = data
    }
    let dest = "\(iconsetDir)/\(name)"
    try! cache[size]!.write(to: URL(fileURLWithPath: dest))
    print("  \(name)")
}

// Convert iconset → .icns
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments  = ["-c", "icns", iconsetDir, "-o", icnsPath]
task.launch()
task.waitUntilExit()

guard task.terminationStatus == 0 else {
    print("❌ iconutil failed"); exit(1)
}

print("\n✓ \(icnsPath)")
