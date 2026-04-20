import AppKit

enum AppActivation {
    static func activate(_ app: NSRunningApplication) {
        guard !app.isTerminated else { return }
        NSApplication.shared.yieldActivation(to: app)
        app.activate()
    }
}
