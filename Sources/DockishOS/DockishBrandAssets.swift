import AppKit

enum DockishBrandAssets {
    static let menuBarIconSize = NSSize(width: 18, height: 18)

    static func applicationIcon(size: NSSize) -> NSImage {
        if let appIcon = resolvedApplicationIcon() {
            return resized(appIcon, to: size)
        }
        return renderedFallbackIcon(size: size)
    }

    private static func resolvedApplicationIcon() -> NSImage? {
        guard let appIcon = NSApp.applicationIconImage else {
            return nil
        }
        guard appIcon.size.width > 0, appIcon.size.height > 0 else {
            return nil
        }
        return appIcon
    }

    private static func resized(_ source: NSImage, to size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let drawRect = fittedRect(for: source.size, inside: rect)
            source.draw(in: drawRect)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func fittedRect(for sourceSize: NSSize, inside rect: NSRect) -> NSRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return rect }
        let scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
        let width = sourceSize.width * scale
        let height = sourceSize.height * scale
        return NSRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func renderedFallbackIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        drawIcon(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawIcon(in rect: NSRect) {
        let side = min(rect.width, rect.height)
        let canvas = NSRect(x: rect.minX, y: rect.minY, width: side, height: side)

        let background = NSBezierPath(
            roundedRect: canvas,
            xRadius: side * 0.23,
            yRadius: side * 0.23
        )
        background.addClip()

        NSGradient(
            starting: NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.20, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)
        )!.draw(in: canvas, angle: -90)

        let dockRect = NSRect(
            x: canvas.minX + side * 0.11,
            y: canvas.minY + side * 0.18,
            width: side * 0.78,
            height: side * 0.18
        )
        let dock = NSBezierPath(
            roundedRect: dockRect,
            xRadius: dockRect.height * 0.32,
            yRadius: dockRect.height * 0.32
        )
        NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
        dock.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
        dock.lineWidth = max(0.8, side * 0.004)
        dock.stroke()

        let chipPad = dockRect.height * 0.20
        let chipHeight = dockRect.height - chipPad * 2
        let spaceChipWidth = chipHeight * 1.1
        let chipY = dockRect.minY + chipPad
        let chipX = dockRect.minX + chipPad

        let firstSpace = NSRect(x: chipX, y: chipY, width: spaceChipWidth, height: chipHeight)
        NSColor.white.withAlphaComponent(0.96).setFill()
        NSBezierPath(
            roundedRect: firstSpace,
            xRadius: chipHeight * 0.22,
            yRadius: chipHeight * 0.22
        ).fill()

        let secondSpace = NSRect(
            x: chipX + spaceChipWidth + chipPad * 0.7,
            y: chipY,
            width: spaceChipWidth,
            height: chipHeight
        )
        NSColor(calibratedWhite: 1.0, alpha: 0.20).setFill()
        NSBezierPath(
            roundedRect: secondSpace,
            xRadius: chipHeight * 0.22,
            yRadius: chipHeight * 0.22
        ).fill()

        let activeWidth = dockRect.width * 0.42
        let activeX = dockRect.maxX - chipPad - activeWidth
        let activeRect = NSRect(x: activeX, y: chipY, width: activeWidth, height: chipHeight)
        let activePath = NSBezierPath(
            roundedRect: activeRect,
            xRadius: chipHeight * 0.22,
            yRadius: chipHeight * 0.22
        )
        NSColor(calibratedRed: 0.30, green: 0.55, blue: 1.0, alpha: 0.35).setFill()
        activePath.fill()
        NSColor(calibratedRed: 0.55, green: 0.75, blue: 1.0, alpha: 0.95).setStroke()
        activePath.lineWidth = max(0.8, side * 0.005)
        activePath.stroke()

        let dotRadius = chipHeight * 0.16
        let dotRect = NSRect(
            x: activeX + chipHeight * 0.30 - dotRadius,
            y: chipY + chipHeight / 2 - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
}
