import AppKit
import Combine

/// Minimal menu-bar item so users have a way to quit the app, open
/// settings, and toggle quick system actions when no terminal is attached.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let titleItem: NSMenuItem
    private let launcherItem: NSMenuItem
    private let utilitySectionsItem: NSMenuItem
    private let collapsedTabPositionItem: NSMenuItem
    private let collapsedTabPositionMenu = NSMenu()
    private var collapsedTabPositionOptions: [CollapsedTabPosition: NSMenuItem] = [:]
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        titleItem = NSMenuItem(title: Self.menuTitle, action: nil, keyEquivalent: "")
        launcherItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        utilitySectionsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        collapsedTabPositionItem = NSMenuItem(title: "Collapsed Tab Position", action: nil, keyEquivalent: "")
        super.init()
        if let button = statusItem.button {
            let icon = DockishBrandAssets.applicationIcon(size: DockishBrandAssets.menuBarIconSize)
            icon.accessibilityDescription = "DockishOS"
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.toolTip = "DockishOS"
        }
        buildMenu()
        bindMenuState()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func buildMenu() {
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        launcherItem.image = Self.menuIcon(systemName: "magnifyingglass")
        launcherItem.action = #selector(openLauncher)
        launcherItem.target = self
        menu.addItem(launcherItem)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.image = Self.menuIcon(systemName: "gearshape")
        settings.target = self
        menu.addItem(settings)

        utilitySectionsItem.image = Self.barMenuIcon(collapsed: SettingsStore.shared.barCollapsed)
        utilitySectionsItem.action = #selector(toggleUtilitySections)
        utilitySectionsItem.target = self
        menu.addItem(utilitySectionsItem)

        buildCollapsedTabPositionMenu()
        collapsedTabPositionItem.image = Self.menuIcon(systemName: "arrow.left.and.right")
        collapsedTabPositionItem.submenu = collapsedTabPositionMenu
        menu.addItem(collapsedTabPositionItem)

        menu.addItem(.separator())

        let github = NSMenuItem(
            title: "Open GitHub Repo",
            action: #selector(openRepo),
            keyEquivalent: ""
        )
        github.image = Self.menuIcon(systemName: "globe")
        github.target = self
        menu.addItem(github)

        menu.addItem(.separator())

        if Updater.shared.canUpdate {
            let updates = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            )
            updates.image = Self.menuIcon(systemName: "arrow.triangle.2.circlepath")
            updates.target = self
            menu.addItem(updates)
            menu.addItem(.separator())
        }
        let quit = NSMenuItem(
            title: "Quit DockishOS",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.image = Self.menuIcon(systemName: "power")
        quit.target = self
        menu.addItem(quit)
    }

    private func buildCollapsedTabPositionMenu() {
        CollapsedTabPosition.allCases.forEach { position in
            let item = NSMenuItem(
                title: position.displayName,
                action: #selector(selectCollapsedTabPosition(_:)),
                keyEquivalent: ""
            )
            item.image = Self.collapsedTabPositionIcon(for: position)
            item.target = self
            item.representedObject = position.rawValue
            collapsedTabPositionMenu.addItem(item)
            collapsedTabPositionOptions[position] = item
        }
    }

    private func bindMenuState() {
        SettingsStore.shared.$launcherHotkey
            .map(Self.launcherMenuTitle(for:))
            .removeDuplicates()
            .sink { [weak self] title in
                self?.launcherItem.title = title
            }
            .store(in: &cancellables)

        SettingsStore.shared.$barCollapsed
            .map(Self.barMenuTitle(collapsed:))
            .removeDuplicates()
            .sink { [weak self] title in
                self?.utilitySectionsItem.title = title
                self?.utilitySectionsItem.image = Self.barMenuIcon(collapsed: SettingsStore.shared.barCollapsed)
            }
            .store(in: &cancellables)
    }

    private static func launcherMenuTitle(for hotkey: LauncherHotkey) -> String {
        "Open Launcher  \(hotkey.displayString)"
    }

    private static func menuIcon(systemName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        guard let base = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }

    private static func collapsedTabPositionIcon(for position: CollapsedTabPosition) -> NSImage? {
        menuIcon(systemName: position.isRightEdge ? "arrow.down.right" : "arrow.down.left")
    }

    private static var menuTitle: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "DockishOS - v\(version)"
    }

    private static func barMenuIcon(collapsed: Bool) -> NSImage? {
        menuIcon(systemName: collapsed ? "chevron.up" : "chevron.down")
    }

    private static func barMenuTitle(collapsed: Bool) -> String {
        collapsed ? "Expand Bar" : "Collapse Bar"
    }

    // NSMenuDelegate — refresh the Dock toggle's checkmark each time the
    // menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        titleItem.title = Self.menuTitle
        launcherItem.title = Self.launcherMenuTitle(for: SettingsStore.shared.launcherHotkey)
        utilitySectionsItem.title = Self.barMenuTitle(collapsed: SettingsStore.shared.barCollapsed)
        utilitySectionsItem.image = Self.barMenuIcon(collapsed: SettingsStore.shared.barCollapsed)
        updateCollapsedTabPositionState()
    }

    private func updateCollapsedTabPositionState() {
        let selected = SettingsStore.shared.collapsedTabPosition
        for (position, item) in collapsedTabPositionOptions {
            item.state = position == selected ? .on : .off
        }
    }

    @objc private func openLauncher()  { LauncherController.shared.toggle() }
    @objc private func openSettings()  { SettingsController.shared.show() }
    @objc private func toggleUtilitySections() { SettingsStore.shared.barCollapsed.toggle() }
    @objc private func selectCollapsedTabPosition(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let position = CollapsedTabPosition(rawValue: rawValue)
        else { return }
        SettingsStore.shared.collapsedTabPosition = position
        updateCollapsedTabPositionState()
    }
    @objc private func checkForUpdates()    { Updater.shared.checkForUpdates() }
    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/8bittts/dockishOS") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
