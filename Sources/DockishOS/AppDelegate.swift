import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bars: [BarController] = []
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
        menuBar = MenuBarController()
        rebuildBars()
        registerHotkeys()
        Updater.startIfAvailable()

        let screenCount = NSScreen.screens.count
        Diagnostics.lifecycle.notice("DockishOS launched (screens=\(screenCount, privacy: .public))")
        if screenCount == 0 {
            Diagnostics.lifecycle.fault("No displays detected at launch — bars will appear when one connects.")
        }

        let center = NotificationCenter.default
        center.observeOnMain(NSApplication.didChangeScreenParametersNotification) { [weak self] _ in
            self?.rebuildBars()
        }
        center.observeOnMain(.dockishBarLayoutDidChange) { [weak self] _ in self?.rebuildBars() }
        center.observeOnMain(.dockishHotkeyDidChange) { [weak self] _ in self?.registerHotkeys() }
    }

    private func rebuildBars() {
        bars.forEach { $0.close() }
        bars = NSScreen.screens
            .filter(SettingsStore.shared.isScreenEnabled)
            .map(BarController.init)
        bars.forEach { $0.show() }
    }

    /// Loads the bundle's icon file as drawn. Left to AppKit, the app icon
    /// comes back through the system icon mask, which rounds the corners of
    /// the mark in the collapse button, the edge tab and the About tab.
    private func installApplicationIcon() {
        guard
            let url = Bundle.main.url(forResource: "DockishOS", withExtension: "icns"),
            let icon = NSImage(contentsOf: url)
        else { return }
        NSApp.applicationIconImage = icon
    }

    private func registerHotkeys() {
        let settings = SettingsStore.shared
        HotkeyManager.shared.register(.launcher, hotkey: settings.launcherHotkey) {
            LauncherController.shared.toggle()
        }
        HotkeyManager.shared.register(.switcher, hotkey: settings.switcherHotkey) {
            SwitcherController.shared.toggle()
        }
    }
}
