#!/usr/bin/env swift
//
// generate-app-icon.swift
// Procedurally generates DockishOS.iconset (and the source PNG) from
// CoreGraphics primitives. Run from the repo root:
//
//   swift scripts/generate-app-icon.swift
//   iconutil -c icns build/DockishOS.iconset -o build/DockishOS.icns
//

import AppKit
import Foundation

let iconsetDir = "build/DockishOS.iconset"
let sourcePng = "build/dockishos.png"
let baseSize = 1024

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try! fm.createDirectory(atPath: "build", withIntermediateDirectories: true)

func makeImage(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
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
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    let s = CGFloat(size)

    // Squircle background with subtle gradient (matches macOS 14+ icon shape).
    let cornerRadius = s * 0.225
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                              xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    let topColor = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.20, alpha: 1)
    let bottomColor = NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.10, alpha: 1)
    let gradient = NSGradient(starting: topColor, ending: bottomColor)!
    gradient.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)

    // Floating bar: rounded translucent rectangle near the bottom.
    let barH = s * 0.18
    let barW = s * 0.78
    let barX = (s - barW) / 2
    let barY = s * 0.18
    let barRect = NSRect(x: barX, y: barY, width: barW, height: barH)
    let barRadius = barH * 0.32
    let barPath = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)

    NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
    barPath.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
    barPath.lineWidth = max(1, s * 0.004)
    barPath.stroke()

    // Three chips inside the bar (Spaces switcher motif on the left, two
    // window chips on the right).
    let chipPad = barH * 0.20
    let chipH = barH - chipPad * 2
    let spaceChipW = chipH * 1.1
    let spaceChipY = barY + chipPad
    let spaceChipX = barX + chipPad

    // Active Space chip (filled white).
    let activeRect = NSRect(x: spaceChipX, y: spaceChipY, width: spaceChipW, height: chipH)
    let activePath = NSBezierPath(roundedRect: activeRect, xRadius: chipH * 0.22, yRadius: chipH * 0.22)
    NSColor.white.setFill()
    activePath.fill()

    // Inactive Space chip.
    let inactiveRect = NSRect(x: spaceChipX + spaceChipW + chipPad * 0.7,
                              y: spaceChipY, width: spaceChipW, height: chipH)
    let inactivePath = NSBezierPath(roundedRect: inactiveRect,
                                    xRadius: chipH * 0.22, yRadius: chipH * 0.22)
    NSColor(calibratedWhite: 1.0, alpha: 0.20).setFill()
    inactivePath.fill()

    // Window chip (wider).
    let winChipW = barW * 0.42
    let winChipX = barX + barW - chipPad - winChipW
    let winChipRect = NSRect(x: winChipX, y: spaceChipY, width: winChipW, height: chipH)
    let winChipPath = NSBezierPath(roundedRect: winChipRect,
                                   xRadius: chipH * 0.22, yRadius: chipH * 0.22)
    NSColor(calibratedRed: 0.30, green: 0.55, blue: 1.0, alpha: 0.35).setFill()
    winChipPath.fill()
    NSColor(calibratedRed: 0.55, green: 0.75, blue: 1.0, alpha: 0.95).setStroke()
    winChipPath.lineWidth = max(1, s * 0.005)
    winChipPath.stroke()

    // Tiny indicator dot inside the window chip (the "frontmost" cue).
    let dotR = chipH * 0.16
    let dotRect = NSRect(x: winChipX + chipH * 0.30 - dotR,
                         y: spaceChipY + chipH / 2 - dotR,
                         width: dotR * 2, height: dotR * 2)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    NSGraphicsContext.current = nil
    return rep
}

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

print("Generating DockishOS app icon (procedural)...")

let baseImage = makeImage(size: baseSize)
if let pngData = baseImage.representation(using: .png, properties: [:]) {
    try! pngData.write(to: URL(fileURLWithPath: sourcePng))
    print("  wrote \(sourcePng) (\(baseSize)x\(baseSize))")
}

for entry in sizes {
    let rep = makeImage(size: entry.px)
    let path = "\(iconsetDir)/\(entry.name).png"
    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path)")
    }
}

print("Done. Now run:")
print("  iconutil -c icns \(iconsetDir) -o build/DockishOS.icns")
