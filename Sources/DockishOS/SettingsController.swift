import AppKit
import SwiftUI

/// Single-instance Settings window with the standard toolbar of panes. The
/// first call to `show()` creates it; later calls bring it forward.
@MainActor
final class SettingsController {
    static let shared = SettingsController()

    private lazy var window: NSWindow = {
        let panes = SettingsPanesController()
        panes.tabStyle = .toolbar
        for pane in SettingsPane.allCases {
            let host = NSHostingController(rootView: SettingsPaneView(pane: pane))
            // Each pane reports its content's height, and the window follows.
            host.sizingOptions = .preferredContentSize
            let item = NSTabViewItem(viewController: host)
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: nil)
            panes.addTabViewItem(item)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsPane.width, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = panes
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

/// Toolbar of panes that names the window after the selected pane, as a
/// macOS settings window does.
private final class SettingsPanesController: NSTabViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        updateWindowTitle()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        view.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }
}
