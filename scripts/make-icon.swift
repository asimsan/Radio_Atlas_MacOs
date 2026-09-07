// Renders AppIcon.icns from the SF Symbol used in the menu bar, on the
// app's own dark background. Run via `swift scripts/make-icon.swift <out.icns>`.
import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.icns"

// Matches Palette.background / Palette.accent so the icon reads as the app.
let bg1 = NSColor(srgbRed: 0x1A / 255, green: 0x1A / 255, blue: 0x28 / 255, alpha: 1)
let bg2 = NSColor(srgbRed: 0x0B / 255, green: 0x0B / 255, blue: 0x12 / 255, alpha: 1)
let glyphColor = NSColor(srgbRed: 0x9A / 255, green: 0x9A / 255, blue: 0xC8 / 255, alpha: 1)

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // macOS icons are a squircle inset from the full canvas, not edge-to-edge.
    let inset = s * 0.08
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.2237, yRadius: s * 0.2237)
    path.addClip()
    NSGradient(starting: bg1, ending: bg2)?.draw(in: rect, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.56, weight: .light)
    if let symbol = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        glyphColor.set()
        NSRect(origin: .zero, size: symbol.size).fill()
        symbol.draw(at: .zero, from: NSRect(origin: .zero, size: symbol.size),
                    operation: .destinationIn, fraction: 1)
        tinted.unlockFocus()

        let g = tinted.size
        tinted.draw(in: NSRect(x: (s - g.width) / 2, y: (s - g.height) / 2,
                               width: g.width, height: g.height))
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("failed to render \(size)px")
    }
    return png
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("AppIcon-\(getpid()).iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The set of names `iconutil` expects; each @2x is the next size up.
for (base, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                     (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
                     (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", outPath]
try task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(task.terminationStatus)
