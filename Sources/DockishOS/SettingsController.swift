import AppKit
import SwiftUI

/// Single-instance Settings window. The first call to `show()` creates it;
/// subsequent calls focus the existing window.
final class SettingsController {
    static let shared = SettingsController()

    private var window: NSWindow?

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let host = NSHostingView(rootView: SettingsView(
            settings: SettingsStore.shared,
            pinned: PinnedAppsStore.shared
        ))

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "DockishOS Settings"
        w.minSize = NSSize(width: 480, height: 460)
        w.contentView = host
        w.isReleasedWhenClosed = false
        w.center()
        w.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window = w
    }
}
