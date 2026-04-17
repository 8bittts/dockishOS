import AppKit
import Combine

struct WindowGroup: Identifiable {
    var id: String { key }
    let key: String
    let bundleID: String?
    let pid: pid_t
    let ownerName: String
    let windows: [WindowInfo]
}

/// Observable list of windows on the current Space.
/// All access must occur on the main thread (SwiftUI + Timer.main).
final class WindowStore: ObservableObject {
    static let shared = WindowStore()

    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var frontmostPID: pid_t = 0
    private var lastActivatedIndex: [String: Int] = [:]
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.frontmostPID = app.processIdentifier
            }
        }
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
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

    /// Group windows by bundle ID (or PID as fallback) for the
    /// "group windows by app" rendering mode.
    func grouped() -> [WindowGroup] {
        var byKey: [String: [WindowInfo]] = [:]
        for w in windows {
            let key = w.bundleID ?? "pid:\(w.pid)"
            byKey[key, default: []].append(w)
        }
        return byKey.compactMap { key, ws -> WindowGroup? in
            guard let first = ws.first else { return nil }
            return WindowGroup(
                key: key,
                bundleID: first.bundleID,
                pid: first.pid,
                ownerName: first.ownerName,
                windows: ws
            )
        }
        .sorted { $0.ownerName.localizedCaseInsensitiveCompare($1.ownerName) == .orderedAscending }
    }

    /// Activate the next window in the group (round-robin). Used when
    /// "group windows by app" is on and the user clicks an app chip.
    func activateNext(in group: WindowGroup) {
        guard !group.windows.isEmpty else { return }
        let last = lastActivatedIndex[group.key] ?? -1
        let next = (last + 1) % group.windows.count
        lastActivatedIndex[group.key] = next
        activate(group.windows[next])
    }

    /// Window most relevant for hover/preview in grouped mode (the one the
    /// next click will raise).
    func nextWindow(in group: WindowGroup) -> WindowInfo? {
        guard !group.windows.isEmpty else { return nil }
        let last = lastActivatedIndex[group.key] ?? -1
        let next = (last + 1) % group.windows.count
        return group.windows[next]
    }
}
