import AppKit
import Combine
import DockishOSCore
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
    private var lastActivatedWindowID: [String: CGWindowID] = [:]
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
        // Refresh races can briefly surface the same CGWindowID twice;
        // keep the last copy rather than trapping on a duplicate key.
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        return WindowGrouping.group(windows.map { window in
            WindowGroupingInput(
                id: window.id,
                pid: window.pid,
                ownerName: window.ownerName,
                bundleID: window.bundleID
            )
        }).compactMap { group -> WindowGroup? in
            let groupedWindows = group.windowIDs.compactMap { byID[$0] }
            guard !groupedWindows.isEmpty else { return nil }
            return WindowGroup(
                key: group.key,
                bundleID: group.bundleID,
                pid: group.pid,
                ownerName: group.ownerName,
                windows: groupedWindows
            )
        }
    }

    /// Activate the next window in the group (round-robin). Used when
    /// "group windows by app" is on and the user clicks an app chip.
    func activateNext(in group: WindowGroup) {
        guard !group.windows.isEmpty else { return }
        // Cycle over a stable order (by window ID) that does not reshuffle as
        // windows are raised, and track the last-activated CGWindowID rather
        // than a positional index into the z-ordered, per-refresh-rebuilt list.
        let ordered = group.windows.sorted { $0.id < $1.id }
        let currentIndex = lastActivatedWindowID[group.key]
            .flatMap { id in ordered.firstIndex { $0.id == id } } ?? -1
        let next = (currentIndex + 1) % ordered.count
        let target = ordered[next]
        lastActivatedWindowID[group.key] = target.id
        activate(target)
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
