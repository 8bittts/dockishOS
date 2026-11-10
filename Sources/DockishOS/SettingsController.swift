import AppKit
import SwiftUI

/// Single-instance Settings window with the standard toolbar of panes. The
/// first call to `show()` creates it; later calls bring it forward.
@MainActor
final class SettingsController {
    static let shared = SettingsController()

    private lazy var window: NSWindow = {
        let panes = NSTabViewController()
        panes.tabStyle = .toolbar
        for pane in SettingsPane.allCases {
            let item = NSTabViewItem(viewController: NSHostingController(rootView: SettingsPaneView(pane: pane)))
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: nil)
            panes.addTabViewItem(item)
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsPane.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = panes
        window.title = "DockishOS Settings"
        window.toolbarStyle = .preference
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
