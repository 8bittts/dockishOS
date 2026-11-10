import AppKit

@MainActor
enum DockishBrandAssets {
    static let menuBarIconSize = NSSize(width: 18, height: 18)

    /// The app icon as macOS renders it, with the system icon mask, drawn at
    /// `size` so SwiftUI lays it out at the size it was rendered for.
    /// Unbundled runs get the system's generic app icon.
    static func applicationIcon(size: NSSize) -> NSImage {
        let icon: NSImage = NSApp.applicationIconImage
        return NSImage(size: size, flipped: false) { rect in
            icon.draw(in: rect)
            return true
        }
    }

    /// Black-and-clear silhouette for the status item so the system can tint
    /// it on light and dark menu bars. Not the color app icon.
    static func menuBarTemplateIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            // Dock silhouette only — no filled square — so the menu bar shows through.
            let side = min(rect.width, rect.height)
            let dock = NSRect(
                x: rect.minX + side * 0.08,
                y: rect.minY + side * 0.32,
                width: side * 0.84,
                height: side * 0.36
            )
            let radius = dock.height * 0.32
            NSColor.black.setFill()
            NSBezierPath(roundedRect: dock, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
