import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bars: [BarController] = []
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        rebuildBars()
        registerHotkey()
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
        center.observeOnMain(.dockishBarLayoutDidChange) { [weak self] _ in self?.applyLayoutChange() }
        center.observeOnMain(.dockishHotkeyDidChange) { [weak self] _ in self?.registerHotkey() }
    }

    /// Size, position and corner move the existing bars, so nothing closes
    /// and reopens on screen. Only a change to which displays show a bar
    /// builds the bars again.
    private func applyLayoutChange() {
        let enabled = NSScreen.screens.filter(SettingsStore.shared.isScreenEnabled).map(\.displayUUID)
        guard enabled == bars.map(\.displayUUID) else {
            rebuildBars()
            return
        }
        bars.forEach { $0.followSettings() }
    }

    private func rebuildBars() {
        bars.forEach { $0.close() }
        bars = NSScreen.screens
            .filter(SettingsStore.shared.isScreenEnabled)
            .map(BarController.init)
        bars.forEach { $0.show() }
    }

    private func registerHotkey() {
        HotkeyManager.shared.register(SettingsStore.shared.switcherHotkey) {
            SwitcherController.shared.toggle()
        }
    }
}
