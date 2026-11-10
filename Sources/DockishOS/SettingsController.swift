import AppKit
import SwiftUI

/// Single-instance Settings window. The first call to `show()` creates it;
/// subsequent calls focus the existing window.
@MainActor
final class SettingsController {
    static let shared = SettingsController()

    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DockishOS Settings"
        window.contentView = NSHostingView(rootView: SettingsView(
            settings: SettingsStore.shared,
            pinned: PinnedAppsStore.shared
        ))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.center()
        return window
    }()

    func show() {
        AppActivation.activateSelf()
        window.makeKeyAndOrderFront(nil)
    }
}
