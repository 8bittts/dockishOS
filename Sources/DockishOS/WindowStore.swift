import AppKit
import Combine

/// Observable list of windows on the current Space.
/// All access must occur on the main thread (SwiftUI + Timer.main).
final class WindowStore: ObservableObject {
    static let shared = WindowStore()

    @Published private(set) var windows: [WindowInfo] = []
    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let next = WindowEnumerator.currentSpaceWindows()
        if next != windows { windows = next }
    }

    func activate(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        app.activate(options: [])
    }
}
