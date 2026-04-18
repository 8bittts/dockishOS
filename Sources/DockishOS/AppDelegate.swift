import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bars: [BarController] = []
    private var menuBar: MenuBarController?
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var layoutObserver: NSObjectProtocol?
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Permissions.warmup()
        installApplicationIcon()
        menuBar = MenuBarController()
        rebuildBars()
        registerLauncherHotkey()

        let screenCount = NSScreen.screens.count
        Diagnostics.lifecycle.notice("DockishOS launched (screens=\(screenCount, privacy: .public))")
        if screenCount == 0 {
            Diagnostics.lifecycle.fault("No displays detected at launch — bars will appear when one connects.")
        }

        // Initialize Sparkle on launch so the auto-check timer starts. Only
        // takes effect when Bundle.main has SUFeedURL — i.e., real `.app`
        // builds, never `swift run`. Touching the singleton is what triggers
        // its `init()`; the discarded reference is intentional.
        if Updater.shared.canUpdate {
            _ = Updater.shared
            Diagnostics.updater.info("Sparkle auto-update enabled")
        } else {
            Diagnostics.updater.info("Running unbundled (no SUFeedURL); auto-update disabled")
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuildBars() }

        layoutObserver = NotificationCenter.default.addObserver(
            forName: .dockishBarLayoutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuildBars() }

        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .dockishHotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.registerLauncherHotkey() }

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in WindowStore.shared.refresh() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let s = screenObserver  { NotificationCenter.default.removeObserver(s) }
        if let s = layoutObserver  { NotificationCenter.default.removeObserver(s) }
        if let s = hotkeyObserver  { NotificationCenter.default.removeObserver(s) }
        if let s = spaceObserver   { NSWorkspace.shared.notificationCenter.removeObserver(s) }
        HotkeyManager.shared.unregister()
    }

    private func rebuildBars() {
        bars.forEach { $0.close() }
        let enabled = NSScreen.screens.filter { SettingsStore.shared.isScreenEnabled($0) }
        bars = enabled.map { BarController(screen: $0) }
        bars.forEach { $0.show() }
    }

    private func registerLauncherHotkey() {
        let launcher = SettingsStore.shared.launcherHotkey
        HotkeyManager.shared.register(
            name: "launcher",
            keyCode: launcher.keyCode,
            modifiers: launcher.carbonModifiers
        ) { LauncherController.shared.toggle() }

        let switcher = SettingsStore.shared.switcherHotkey
        HotkeyManager.shared.register(
            name: "switcher",
            keyCode: switcher.keyCode,
            modifiers: switcher.carbonModifiers
        ) { SwitcherController.shared.toggle() }
    }

    private func installApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "DockishOS", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else { return }
        NSApp.applicationIconImage = icon
    }
}
