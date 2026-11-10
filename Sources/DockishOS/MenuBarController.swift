import AppKit
import Carbon.HIToolbox
import DockishOSCore

/// Status-bar item and its menu: the way to open the launcher and Settings,
/// collapse the bar, switch Spaces, check for updates and quit.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var launcherItem = NSMenuItem()
    private var hotkeyWarningItem = NSMenuItem()
    private var collapseItem = NSMenuItem()
    private var previousSpaceItem = NSMenuItem()
    private var nextSpaceItem = NSMenuItem()
    private var tabPositionItems: [CollapsedTabPosition: NSMenuItem] = [:]

    override init() {
        super.init()
        if let button = statusItem.button {
            let icon = DockishBrandAssets.menuBarTemplateIcon(size: DockishBrandAssets.menuBarIconSize)
            icon.accessibilityDescription = "DockishOS"
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.toolTip = "DockishOS"
        }
        buildMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func buildMenu() {
        let title = menu.addItem(withTitle: "DockishOS - v\(AppVersion.short)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(.separator())

        // `menuNeedsUpdate` gives the launcher, warning and collapse items their titles.
        launcherItem = addItem("", symbol: "magnifyingglass", action: #selector(openLauncher))
        hotkeyWarningItem = addItem("", symbol: "exclamationmark.triangle", action: #selector(openSettings))
        addItem("Settings…", symbol: "gearshape", action: #selector(openSettings), keyEquivalent: ",")
        collapseItem = addItem("", symbol: "chevron.down", action: #selector(toggleCollapse))

        let tabPositionItem = addItem("Collapsed Tab Position", symbol: "arrow.left.and.right", action: nil)
        let tabPositionMenu = NSMenu()
        for position in CollapsedTabPosition.allCases {
            let item = makeItem(
                position.displayName,
                symbol: position.isRightEdge ? "arrow.down.right" : "arrow.down.left",
                action: #selector(selectCollapsedTabPosition(_:))
            )
            item.representedObject = position.rawValue
            tabPositionMenu.addItem(item)
            tabPositionItems[position] = item
        }
        tabPositionItem.submenu = tabPositionMenu

        previousSpaceItem = addItem("Previous Space", symbol: "chevron.up", action: #selector(previousSpace))
        nextSpaceItem = addItem("Next Space", symbol: "chevron.down", action: #selector(nextSpace))
        menu.addItem(.separator())

        addItem("Open GitHub Repo", symbol: "globe", action: #selector(openRepo))
        menu.addItem(.separator())

        if Updater.isAvailable {
            addItem("Check for Updates…", symbol: "arrow.triangle.2.circlepath", action: #selector(checkForUpdates))
            menu.addItem(.separator())
        }
        addItem("Quit DockishOS", symbol: "power", action: #selector(quit), keyEquivalent: "q")
    }

    @discardableResult
    private func addItem(
        _ title: String,
        symbol: String,
        action: Selector?,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = makeItem(title, symbol: symbol, action: action, keyEquivalent: keyEquivalent)
        menu.addItem(item)
        return item
    }

    private func makeItem(
        _ title: String,
        symbol: String,
        action: Selector?,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.image = Self.menuIcon(symbol)
        return item
    }

    private static func menuIcon(_ systemName: String) -> NSImage? {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
    }

    // MARK: - NSMenuDelegate

    /// Brings every state-dependent item up to date each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let settings = SettingsStore.shared
        launcherItem.title = "Open Launcher  \(settings.launcherHotkey.displayString)"
        collapseItem.title = settings.barCollapsed ? "Expand Bar" : "Collapse Bar"
        collapseItem.image = Self.menuIcon(settings.barCollapsed ? "chevron.up" : "chevron.down")
        for (position, item) in tabPositionItems {
            item.state = position == settings.collapsedTabPosition ? .on : .off
        }
        updateHotkeyWarning()
    }

    /// Shows the first hotkey that failed to register, if any.
    private func updateHotkeyWarning() {
        let failed = [HotkeyAction.launcher, .switcher].lazy.compactMap { action in
            HotkeyManager.shared.registrationFailure(for: action).map { (action: action, status: $0) }
        }.first
        hotkeyWarningItem.isHidden = failed == nil
        if let failed {
            let conflict = failed.status == eventHotKeyExistsErr ? " - conflict detected" : ""
            hotkeyWarningItem.title = "\(failed.action.displayName) hotkey unavailable\(conflict)"
        }
    }

    /// The Space next to the active one on the screen under the pointer.
    private func adjacentSpace(direction: Int) -> SpaceInfo? {
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return nil }
        return SpacesAPI.adjacentSpace(for: screen, direction: direction)
    }

    private func switchSpace(direction: Int) {
        guard let space = adjacentSpace(direction: direction) else { return }
        SpacesAPI.switchTo(space)
    }

    // MARK: - NSMenuItemValidation

    /// Disables a Space command at the end it cannot move past. The menu
    /// enables its items automatically, so setting `isEnabled` would not stick.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem {
        case previousSpaceItem: return adjacentSpace(direction: -1) != nil
        case nextSpaceItem: return adjacentSpace(direction: 1) != nil
        default: return true
        }
    }

    // MARK: - Actions

    @objc private func openLauncher() { LauncherController.shared.toggle() }
    @objc private func openSettings() { SettingsController.shared.show() }
    @objc private func toggleCollapse() { SettingsStore.shared.barCollapsed.toggle() }
    @objc private func previousSpace() { switchSpace(direction: -1) }
    @objc private func nextSpace() { switchSpace(direction: 1) }
    @objc private func openRepo() { NSWorkspace.shared.open(AppLinks.repository) }
    @objc private func checkForUpdates() { Updater.shared.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func selectCollapsedTabPosition(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let position = CollapsedTabPosition(rawValue: rawValue)
        else { return }
        SettingsStore.shared.collapsedTabPosition = position
    }
}
