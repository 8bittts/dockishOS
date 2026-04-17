import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bars: [BarController] = []
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Permissions.warmup()
        rebuildBars()
        registerLauncherHotkey()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuildBars() }

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in WindowStore.shared.refresh() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let s = screenObserver { NotificationCenter.default.removeObserver(s) }
        if let s = spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(s) }
        HotkeyManager.shared.unregister()
    }

    private func rebuildBars() {
        bars.forEach { $0.close() }
        bars = NSScreen.screens.map { BarController(screen: $0) }
        bars.forEach { $0.show() }
    }

    /// ⌥Space toggles the launcher. Sticky default; no settings UI yet.
    private func registerLauncherHotkey() {
        HotkeyManager.shared.register {
            LauncherController.shared.toggle()
        }
    }
}
