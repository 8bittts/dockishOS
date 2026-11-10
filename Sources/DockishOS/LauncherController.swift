import AppKit

/// Lifecycle for the launcher panel. Singleton so the global hotkey and the
/// status menu can toggle it.
@MainActor
final class LauncherController {
    static let shared = LauncherController()

    private let panel = HUDPanel(size: NSSize(width: 560, height: 420), accessibilityTitle: "Launcher")
    private let store = LauncherStore()

    private init() {
        panel.setContent(LauncherView(
            store: store,
            pinnedStore: PinnedAppsStore.shared,
            onActivate: { [panel, store] app in
                panel.dismiss()
                store.activate(app)
            },
            onDismiss: { [panel] in panel.dismiss() }
        ))
    }

    func toggle() {
        guard !panel.isVisible else { return panel.dismiss() }
        store.refreshIndex()
        store.reset()
        // Roughly the Spotlight position: centered, a quarter of the way down.
        panel.present { visibleFrame, size in
            NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height - visibleFrame.height * 0.25
            )
        }
    }
}
