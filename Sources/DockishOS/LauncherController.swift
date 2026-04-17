import AppKit
import SwiftUI

/// Lifecycle for the launcher panel. Singleton so the global hotkey can
/// toggle it from anywhere. All methods must be called on the main thread.
final class LauncherController {
    static let shared = LauncherController()

    private let panel: LauncherPanel
    private let host: NSHostingView<LauncherView>
    private var resignObserver: NSObjectProtocol?
    private var previousActiveApp: NSRunningApplication?

    private init() {
        let size = NSSize(width: 560, height: 420)
        panel = LauncherPanel(size: size)
        host = NSHostingView(rootView: LauncherView(store: LauncherStore.shared))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { _ in
            // Hide on click-outside / focus loss.
            DispatchQueue.main.async { LauncherController.shared.hide() }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        LauncherStore.shared.reset()
        positionOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        // Return focus to whatever was frontmost before we opened.
        previousActiveApp?.activate(options: [])
        previousActiveApp = nil
    }

    private func positionOnActiveScreen() {
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        // Roughly Spotlight position: centered horizontally, ~30% from top.
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - visible.height * 0.25
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}
