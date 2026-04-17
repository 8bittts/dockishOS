import AppKit
import Combine

/// Observable list of windows on the current Space.
/// All access must occur on the main thread (SwiftUI + Timer.main).
final class WindowStore: ObservableObject {
    static let shared = WindowStore()

    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var frontmostPID: pid_t = 0
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
}
