import AppKit

@MainActor
enum AppActivation {
    /// Hands activation to another app (cooperative activation, macOS 14+).
    static func activate(_ app: NSRunningApplication) {
        guard !app.isTerminated else { return }
        NSApp.yieldActivation(to: app)
        app.activate()
    }

    /// Brings DockishOS forward so the Settings window or Sparkle's update
    /// window can take key focus.
    ///
    /// `activate(ignoringOtherApps:)` is deprecated, but its replacement
    /// `activate()` is a request the system declines for an accessory app that
    /// no other app yielded to: measured on macOS 27, the app stays inactive
    /// and its window never becomes key.
    static func activateSelf() {
        // AppKit can report the app as active while another app is frontmost:
        // after a background launch, and after `activate(_:)` hands activation
        // away. Activating then does nothing, so clear the stale state first.
        let isFrontmost = NSWorkspace.shared.frontmostApplication == .current
        if NSApp.isActive, !isFrontmost {
            NSApp.deactivate()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Activates the running app with `bundleID`. Returns false when no such
    /// app is running.
    static func activateRunningApp(bundleID: String?) -> Bool {
        guard
            let bundleID,
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else { return false }
        activate(app)
        return true
    }

    /// Launches the app bundle at `url`, and beeps when it cannot open.
    static func launch(at url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            Diagnostics.lifecycle.error(
                "launch failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            NSSound.beep()
        }
    }
}
