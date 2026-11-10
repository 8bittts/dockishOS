import AppKit
import Combine
import DockishOSCore

/// Observable list of windows on the current Space.
@MainActor
final class WindowStore: ObservableObject {
    static let shared = WindowStore()

    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var frontmostPID: pid_t = 0
    /// Per group, the window the last click on its chip raised.
    private var lastActivatedWindowID: [AppWindowGroup.ID: CGWindowID] = [:]

    private init() {
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        refresh()
        // The window server posts no notification when a window opens, closes
        // or changes title, so poll.
        Timer.repeating(every: 1.0) { [weak self] in self?.refresh() }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.observeOnMain(NSWorkspace.didActivateApplicationNotification) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let self, let app else { return }
            self.frontmostPID = app.processIdentifier
            self.refresh()
        }
        workspace.observeOnMain(NSWorkspace.activeSpaceDidChangeNotification) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let next = WindowEnumerator.currentSpaceWindows()
        if next != windows { windows = next }
    }

    func activate(_ window: WindowInfo) {
        WindowControl.raise(window)
    }

    func close(_ window: WindowInfo) {
        WindowControl.close(window)
        refresh()
    }

    /// Activate the next window in the group (round-robin). Used when
    /// "group windows by app" is on and the user clicks an app chip.
    func activateNext(in group: AppWindowGroup) {
        // Cycle over a stable order (by window ID) that does not reshuffle as
        // windows are raised, tracking the last-activated CGWindowID rather than
        // a positional index into the z-ordered, per-refresh-rebuilt list.
        guard
            let nextID = WindowCycle.next(ids: group.windows.map(\.id), after: lastActivatedWindowID[group.id]),
            let target = group.windows.first(where: { $0.id == nextID })
        else { return }
        lastActivatedWindowID[group.id] = target.id
        activate(target)
    }
}
