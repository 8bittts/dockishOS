import AppKit

/// Minimal menu-bar item so users have a way to quit the app and surface
/// help when no terminal is attached (i.e. when launched from the DMG).
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockishOS")
            button.image?.isTemplate = true
            button.toolTip = "DockishOS"
        }
        buildMenu()
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

    @objc private func openLauncher() {
        LauncherController.shared.toggle()
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/8bittts/dockishOS") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
