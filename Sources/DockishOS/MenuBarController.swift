import AppKit
import Carbon.HIToolbox

/// Status-bar item and its menu: About, the YEN Terminal link, Settings,
/// the project page, updates and Quit. Bar and Space commands live on the
/// bar, in Settings and in macOS itself, not here.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var hotkeyWarningItem = NSMenuItem()

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
        addItem("About DockishOS", symbol: "info.circle", action: #selector(showAbout))
        addItem("YEN Terminal", symbol: "terminal", action: #selector(openYenTerminal))
        menu.addItem(.separator())

        // Shown only while the switcher shortcut cannot be registered;
        // `menuNeedsUpdate` gives it its title.
        hotkeyWarningItem = addItem("", symbol: "exclamationmark.triangle", action: #selector(openSettings))
        addItem("Settings…", symbol: "gearshape", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())

        addItem("GitHub Project", symbol: "chevron.left.forwardslash.chevron.right", action: #selector(openRepo))
        if Updater.isAvailable {
            addItem("Check for Updates…", symbol: "arrow.triangle.2.circlepath", action: #selector(checkForUpdates))
        }
        menu.addItem(.separator())
        // The app has no Dock icon, so this is the only way to quit it.
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

    /// Shows a warning while the app switcher's shortcut cannot be registered.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let failure = HotkeyManager.shared.registrationFailure
        hotkeyWarningItem.isHidden = failure == nil
        hotkeyWarningItem.title = failure == OSStatus(eventHotKeyExistsErr)
            ? "App Switcher Shortcut Is in Use"
            : "App Switcher Shortcut Unavailable"
    }

    // MARK: - Actions

    @objc private func openSettings() { SettingsController.shared.show() }

    /// The standard About panel: icon, name, version and copyright from the bundle.
    @objc private func showAbout() {
        AppActivation.activateSelf()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openYenTerminal() { NSWorkspace.shared.open(AppLinks.yenTerminal) }
    @objc private func openRepo() { NSWorkspace.shared.open(AppLinks.repository) }
    @objc private func checkForUpdates() { Updater.shared.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
}
