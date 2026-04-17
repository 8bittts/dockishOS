import AppKit

/// Single floating panel that shows a window thumbnail when the user hovers
/// a window chip. Debounced show + hide so sweeping the cursor across the
/// bar doesn't flash thumbnails for every chip in turn.
@MainActor
final class ThumbnailController {
    static let shared = ThumbnailController()

    private let panel: NSPanel
    private let imageView: NSImageView
    private let captionLabel: NSTextField
    private var pendingShow: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?
    private var currentWindow: WindowInfo?
    private var cache: [CGWindowID: (image: NSImage, at: Date)] = [:]
    private let cacheTTL: TimeInterval = 3.0
    private let showDelay: TimeInterval = 0.2
    private let hideDelay: TimeInterval = 0.1
    private let panelSize = NSSize(width: 360, height: 230)

    private init() {
        let rect = NSRect(origin: .zero, size: panelSize)
        panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        container.autoresizingMask = [.width, .height]

        let blur = NSVisualEffectView(frame: rect)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        container.addSubview(blur)

        captionLabel = NSTextField(frame: NSRect(x: 12, y: 8, width: panelSize.width - 24, height: 18))
        captionLabel.isBezeled = false
        captionLabel.drawsBackground = false
        captionLabel.isEditable = false
        captionLabel.isSelectable = false
        captionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = .labelColor
        captionLabel.lineBreakMode = .byTruncatingTail
        captionLabel.maximumNumberOfLines = 1
        captionLabel.autoresizingMask = [.width]
        container.addSubview(captionLabel)

        let imageRect = NSRect(
            x: 8,
            y: 32,
            width: panelSize.width - 16,
            height: panelSize.height - 40
        )
        imageView = NSImageView(frame: imageRect)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)

        panel.contentView = container
    }

    /// Schedule a thumbnail show for `window`, anchored near `cursor` in
    /// screen coordinates. Calling repeatedly debounces.
    func requestShow(_ window: WindowInfo, near cursor: NSPoint) {
        pendingHide?.cancel()
        pendingShow?.cancel()
        currentWindow = window

        if let cached = cachedImage(for: window.id) {
            actuallyShow(window, image: cached, near: cursor)
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.currentWindow?.id == window.id else { return }
            self.captureAndShow(window, near: cursor)
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    /// Schedule a hide. Cancelled if `requestShow` is called before it fires
    /// (so chip-to-chip sweeps don't flicker the panel off and on).
    func cancelShow() {
        pendingShow?.cancel()
        pendingShow = nil
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.currentWindow = nil
            self?.panel.orderOut(nil)
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: work)
    }

    private func cachedImage(for id: CGWindowID) -> NSImage? {
        guard let entry = cache[id] else { return nil }
        if Date().timeIntervalSince(entry.at) > cacheTTL { return nil }
        return entry.image
    }

    private func captureAndShow(_ window: WindowInfo, near cursor: NSPoint) {
        Task { [weak self] in
            guard let image = await ThumbnailCapture.capture(windowID: window.id) else { return }
            await MainActor.run {
                guard let self, self.currentWindow?.id == window.id else { return }
                self.cache[window.id] = (image, Date())
                self.actuallyShow(window, image: image, near: cursor)
            }
        }
    }

    private func actuallyShow(_ window: WindowInfo, image: NSImage, near cursor: NSPoint) {
        captionLabel.stringValue = window.displayTitle
        imageView.image = image
        let origin = anchorOrigin(near: cursor)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    /// Center horizontally on cursor X, sit just above cursor Y, clamped
    /// to the screen the cursor is on.
    private func anchorOrigin(near cursor: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let frame = screen.visibleFrame
        let rawX = cursor.x - panelSize.width / 2
        let rawY = cursor.y + 16
        let x = max(frame.minX + 8, min(frame.maxX - panelSize.width - 8, rawX))
        let y = max(frame.minY + 8, min(frame.maxY - panelSize.height - 8, rawY))
        return NSPoint(x: x, y: y)
    }
}
