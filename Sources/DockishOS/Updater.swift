import AppKit
import Sparkle

/// Sparkle-driven auto-update controller. Reads its feed URL + EdDSA
/// public key from the bundled `Info.plist`, so no extra runtime
/// configuration is needed.
///
/// Held as a singleton because Sparkle requires a long-lived updater
/// object to run its scheduled check timer (`SUEnableAutomaticChecks`).
/// Touching `.shared` from `applicationDidFinishLaunching` is enough to
/// trigger init and start the timer.
///
/// DockishOS runs as an `.accessory` app (`LSUIElement`), so it has no
/// Dock icon and cannot bring its own windows forward on its own. Left
/// alone, Sparkle's "update available" window and its modal alerts open
/// *behind* whatever the user is looking at and are easy to miss. As
/// Sparkle's user-driver delegate this controller temporarily promotes the
/// app to a regular foreground app and floats the update windows above
/// everything for the duration of the session, then restores both the
/// activation policy and the window levels when Sparkle finishes.
final class Updater: NSObject {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController?
    private var activationPolicyBeforeUpdate: NSApplication.ActivationPolicy?
    private var elevatedWindowLevels: [ObjectIdentifier: NSWindow.Level] = [:]
    private var windowObserver: Any?

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /// User-initiated check ("Check for Updates…" menu item).
    @objc func checkForUpdates() {
        presentSparkleUI()
        controller?.checkForUpdates(nil)
    }

    /// True when running from a real `.app` bundle with Sparkle bundled.
    /// `swift run` builds skip Sparkle entirely, so callers should test
    /// this before exposing update affordances.
    var canUpdate: Bool {
        Bundle.main.infoDictionary?["SUFeedURL"] != nil
    }

    // MARK: - Foregrounding an accessory app for the update UI

    private func presentSparkleUI() {
        promoteToForegroundIfNeeded()
        startFloatingWindows()
    }

    private func promoteToForegroundIfNeeded() {
        let currentPolicy = NSApp.activationPolicy()
        if currentPolicy != .regular, activationPolicyBeforeUpdate == nil {
            activationPolicyBeforeUpdate = currentPolicy
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreActivationPolicyIfNeeded() {
        guard let activationPolicyBeforeUpdate else { return }
        NSApp.setActivationPolicy(activationPolicyBeforeUpdate)
        self.activationPolicyBeforeUpdate = nil
    }

    /// Sparkle creates its windows lazily as the session advances, so we
    /// float each one as it becomes key rather than trying to find them up
    /// front. Original levels are saved per-window and restored on teardown,
    /// so DockishOS's own panels are left exactly as they were.
    private func startFloatingWindows() {
        guard windowObserver == nil else { return }
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let window = notification.object as? NSWindow,
                  Self.isSparkleWindow(window) else { return }
            self.floatForUpdateSession(window)
        }
    }

    private static let sparkleBundle = Bundle(identifier: "org.sparkle-project.Sparkle")

    /// Only elevate windows that belong to the Sparkle framework, so opening
    /// the launcher/Settings mid-update doesn't transiently mis-level our own
    /// panels. Falls back to floating any window if the Sparkle bundle can't
    /// be resolved (preserves prior best-effort behavior).
    private static func isSparkleWindow(_ window: NSWindow) -> Bool {
        guard let sparkleBundle else { return true }
        let owners: [AnyClass] = [type(of: window), window.windowController.map { type(of: $0) }].compactMap { $0 }
        return owners.contains { Bundle(for: $0) == sparkleBundle }
    }

    private func floatForUpdateSession(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        if elevatedWindowLevels[id] == nil {
            elevatedWindowLevels[id] = window.level
        }
        window.level = .floating
    }

    private func stopFloatingWindows() {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
            self.windowObserver = nil
        }
        for window in NSApp.windows {
            let id = ObjectIdentifier(window)
            if let originalLevel = elevatedWindowLevels[id] {
                window.level = originalLevel
            }
        }
        elevatedWindowLevels.removeAll()
    }
}

extension Updater: SPUStandardUserDriverDelegate {
    /// DockishOS handles surfacing scheduled update reminders itself: when
    /// Sparkle decides to show an update, `standardUserDriverWillHandleShowingUpdate`
    /// promotes this accessory app to the foreground and floats the update
    /// window so it can't be missed. Declaring support silences Sparkle's
    /// "background app does not implement gentle reminders" warning.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillShowModalAlert() {
        presentSparkleUI()
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate _: SUAppcastItem,
        state _: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        presentSparkleUI()
    }

    func standardUserDriverWillFinishUpdateSession() {
        stopFloatingWindows()
        restoreActivationPolicyIfNeeded()
    }
}
