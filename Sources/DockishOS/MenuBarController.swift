import AppKit

/// Minimal menu-bar item so users have a way to quit the app, open
/// settings, and toggle quick system actions when no terminal is attached.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let dockToggleItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        dockToggleItem = NSMenuItem(title: "Auto-hide system Dock", action: nil, keyEquivalent: "")
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockishOS")
            button.image?.isTemplate = true
            button.toolTip = "DockishOS"
        }
        buildMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func buildMenu() {
        let title = NSMenuItem(title: "DockishOS", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let launcher = NSMenuItem(
            title: "Open Launcher  ⌥Space",
            action: #selector(openLauncher),
            keyEquivalent: ""
        )
        launcher.target = self
        menu.addItem(launcher)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        dockToggleItem.action = #selector(toggleDockAutoHide)
        dockToggleItem.target = self
        menu.addItem(dockToggleItem)

        menu.addItem(.separator())

        let github = NSMenuItem(
            title: "Open GitHub Repo",
            action: #selector(openRepo),
            keyEquivalent: ""
        )
        github.target = self
        menu.addItem(github)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit DockishOS",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    // NSMenuDelegate — refresh the Dock toggle's checkmark each time the
    // menu opens, since the user may have changed it elsewhere.
    func menuNeedsUpdate(_ menu: NSMenu) {
        dockToggleItem.state = DockHelper.isAutoHideEnabled ? .on : .off
    }

    @objc private func openLauncher()  { LauncherController.shared.toggle() }
    @objc private func openSettings()  { SettingsController.shared.show() }
    @objc private func toggleDockAutoHide() { DockHelper.toggleAutoHide() }
    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/8bittts/dockishOS") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
