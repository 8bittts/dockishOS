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
        // Restore after the panes exist; the controller loads its view, and
        // runs `viewDidLoad`, before any pane is added.
        panes.restoreLastPane()

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

/// Toolbar of panes that names the window after the selected pane and opens
/// on the pane last viewed, even after a relaunch, as the HIG asks of a
/// macOS settings window.
private final class SettingsPanesController: NSTabViewController {
    private static let selectedPaneKey = "DockishOS.settingsPane"

    /// Selects the pane last viewed. A saved index from a build with more
    /// panes than this one falls back to the first pane.
    func restoreLastPane() {
        let saved = UserDefaults.standard.integer(forKey: Self.selectedPaneKey)
        selectedTabViewItemIndex = tabViewItems.indices.contains(saved) ? saved : 0
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateWindowTitle()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.selectedPaneKey)
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        view.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }
}
