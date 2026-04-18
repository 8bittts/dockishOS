import AppKit
import Combine
import SwiftUI

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
    private let reorderAnimation = Animation.spring(response: 0.30, dampingFraction: 0.82)
    private let focusAnimation = Animation.easeInOut(duration: 0.18)
    private var lastActivatedIndex: [String: Int] = [:]
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    private init() {
        refresh(animated: false)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.setFrontmostPID(app.processIdentifier, animated: true)
                self?.refresh()
            }
        }
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    }

    func refresh(animated: Bool = true) {
        let next = WindowEnumerator.currentSpaceWindows()
        guard next != windows else { return }
        if animated {
            withAnimation(reorderAnimation) {
                windows = next
            }
        } else {
            windows = next
        }
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
        var orderedKeys: [String] = []
        for w in windows {
            let key = w.bundleID ?? "pid:\(w.pid)"
            if byKey[key] == nil {
                orderedKeys.append(key)
            }
            byKey[key, default: []].append(w)
        }
        return orderedKeys.compactMap { key -> WindowGroup? in
            guard let ws = byKey[key], let first = ws.first else { return nil }
            return WindowGroup(
                key: key,
                bundleID: first.bundleID,
                pid: first.pid,
                ownerName: first.ownerName,
                windows: ws
            )
        }
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

    private func setFrontmostPID(_ pid: pid_t, animated: Bool) {
        guard frontmostPID != pid else { return }
        if animated {
            withAnimation(focusAnimation) {
                frontmostPID = pid
            }
        } else {
            frontmostPID = pid
        }
    }
}
