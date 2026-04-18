#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 6 else {
    fputs("usage: swift scripts/generate-dmg-background.swift <input> <output-1x> <output-2x> <width> <height>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output1xURL = URL(fileURLWithPath: CommandLine.arguments[2])
let output2xURL = URL(fileURLWithPath: CommandLine.arguments[3])

guard
    let width = Int(CommandLine.arguments[4]),
    let height = Int(CommandLine.arguments[5]),
    width > 0,
    height > 0
else {
    fputs("error: width and height must be positive integers\n", stderr)
    exit(1)
}

guard let sourceImage = NSImage(contentsOf: inputURL) else {
    fputs("error: failed to load background image at \(inputURL.path)\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: output1xURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

func aspectFillSourceRect(imageSize: NSSize, targetSize: NSSize) -> NSRect {
    let imageAspect = imageSize.width / imageSize.height
    let targetAspect = targetSize.width / targetSize.height

    if imageAspect > targetAspect {
        let croppedWidth = imageSize.height * targetAspect
        let x = (imageSize.width - croppedWidth) / 2
        return NSRect(x: x, y: 0, width: croppedWidth, height: imageSize.height)
    } else {
        let croppedHeight = imageSize.width / targetAspect
        let y = (imageSize.height - croppedHeight) / 2
        return NSRect(x: 0, y: y, width: imageSize.width, height: croppedHeight)
    }
}

func strokeChevronStack(in size: NSSize) {
    let w = size.width
    let h = size.height
    let centerX = w * 0.185
    // Keep the chevrons centered between the two vertically stacked Finder
    // targets. The previous anchor sat a touch low relative to the app +
    // Applications icon layout.
    let topCenterY = h * 0.578
    let chevronGap = max(14, h * 0.026)
    let chevronWidth = max(28, w * 0.026)
    let chevronHeight = max(10, h * 0.018)
    let strokeWidth = max(1.7, w * 0.00135)

    func chevronPath(centerY: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = strokeWidth
        path.move(to: NSPoint(x: centerX - chevronWidth / 2, y: centerY + chevronHeight / 2))
        path.line(to: NSPoint(x: centerX, y: centerY - chevronHeight / 2))
        path.line(to: NSPoint(x: centerX + chevronWidth / 2, y: centerY + chevronHeight / 2))
        return path
    }

    let centerYs = (0..<3).map { topCenterY - CGFloat($0) * chevronGap }
    let glowAlphas: [CGFloat] = [0.04, 0.06, 0.09]
    let strokeAlphas: [CGFloat] = [0.34, 0.52, 0.74]
    let glowColor = NSColor.white
    let chevronColor = NSColor(
        calibratedRed: 0.09,
        green: 0.12,
        blue: 0.18,
        alpha: 1
    )

    for (index, centerY) in centerYs.enumerated() {
        let glow = NSShadow()
        glow.shadowBlurRadius = max(3.5, w * 0.0028)
        glow.shadowColor = glowColor.withAlphaComponent(glowAlphas[index])
        glow.shadowOffset = .zero

        NSGraphicsContext.saveGraphicsState()
        glow.set()
        chevronColor.withAlphaComponent(strokeAlphas[index] * 0.45).setStroke()
        chevronPath(centerY: centerY).stroke()
        NSGraphicsContext.restoreGraphicsState()

        chevronColor.withAlphaComponent(strokeAlphas[index]).setStroke()
        chevronPath(centerY: centerY).stroke()
    }
}

func renderBackground(to outputURL: URL, size: NSSize) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.black.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    let sourceRect = aspectFillSourceRect(imageSize: sourceImage.size, targetSize: size)
    sourceImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: sourceRect,
        operation: .copy,
        fraction: 1.0
    )

    strokeChevronStack(in: size)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DockishOS.DMGBackground", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to encode PNG"])
    }
    try data.write(to: outputURL)
}

try renderBackground(to: output1xURL, size: NSSize(width: width, height: height))
try renderBackground(to: output2xURL, size: NSSize(width: width * 2, height: height * 2))
