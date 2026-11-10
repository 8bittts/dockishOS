import AppKit
import Sparkle

/// Sparkle-driven auto-update controller. Reads its feed URL + EdDSA
/// public key from the bundled `Info.plist`, so no extra runtime
/// configuration is needed.
///
/// Held as a singleton because Sparkle requires a long-lived updater
/// object to run its scheduled check timer (`SUEnableAutomaticChecks`).
///
/// DockishOS runs as an `.accessory` app (`LSUIElement`), so it has no
/// Dock icon and cannot bring its own windows forward on its own. Left
/// alone, Sparkle's "update available" window and its modal alerts open
/// *behind* whatever the user is looking at and are easy to miss. As
/// Sparkle's user-driver delegate this controller temporarily promotes the
/// app to a regular foreground app and floats the update windows above
/// everything for the duration of the session, then restores both the
/// activation policy and the window levels when Sparkle finishes.
@MainActor
final class Updater: NSObject {
    /// True when running from a real `.app` bundle, whose `Info.plist`
    /// carries the feed URL. `swift run` builds have none, so they must not
    /// start Sparkle or offer update commands.
    static let isAvailable = Bundle.main.infoDictionary?["SUFeedURL"] != nil

    /// Creating the instance starts Sparkle. Use only when `isAvailable`.
    static let shared = Updater()

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    private var activationPolicyBeforeUpdate: NSApplication.ActivationPolicy?
    private var elevatedWindowLevels: [ObjectIdentifier: NSWindow.Level] = [:]
    private var windowObserver: NSObjectProtocol?

    private override init() {
        super.init()
        _ = controller
    }

    /// Starts Sparkle and its scheduled check timer in a bundled build.
    static func startIfAvailable() {
        guard isAvailable else {
            Diagnostics.updater.info("Running unbundled (no SUFeedURL); auto-update disabled")
            return
        }
        _ = shared
        Diagnostics.updater.info("Sparkle auto-update enabled")
    }

    /// User-initiated check ("Check for Updates…" menu item).
    func checkForUpdates() {
        presentSparkleUI()
        controller.checkForUpdates(nil)
    }

    // MARK: - Foregrounding an accessory app for the update UI

    private func presentSparkleUI() {
        if NSApp.activationPolicy() != .regular, activationPolicyBeforeUpdate == nil {
            activationPolicyBeforeUpdate = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
        }
        AppActivation.activateSelf()
        startFloatingWindows()
    }

    /// Sparkle creates its windows lazily as the session advances, so we
    /// float each one as it becomes key rather than trying to find them up
    /// front. Original levels are saved per-window and restored on teardown,
    /// so DockishOS's own panels are left exactly as they were.
    private func startFloatingWindows() {
        guard windowObserver == nil else { return }
        windowObserver = NotificationCenter.default.observeOnMain(
            NSWindow.didBecomeKeyNotification
        ) { [weak self] notification in
            guard let self, let window = notification.object as? NSWindow,
                  Self.isSparkleWindow(window) else { return }
            if self.elevatedWindowLevels[ObjectIdentifier(window)] == nil {
                self.elevatedWindowLevels[ObjectIdentifier(window)] = window.level
            }
            window.level = .floating
        }
    }

    private static let sparkleBundle = Bundle(identifier: "org.sparkle-project.Sparkle")

    /// Only elevate windows that belong to the Sparkle framework, so opening
    /// the launcher/Settings mid-update doesn't transiently mis-level our own
    /// panels. Falls back to floating any window if the Sparkle bundle can't
    /// be resolved.
    private static func isSparkleWindow(_ window: NSWindow) -> Bool {
        guard let sparkleBundle else { return true }
        let owners: [AnyClass] = [type(of: window), window.windowController.map { type(of: $0) }].compactMap { $0 }
        return owners.contains { Bundle(for: $0) == sparkleBundle }
    }

    private func endSparkleUI() {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
            self.windowObserver = nil
        }
        for window in NSApp.windows {
            if let originalLevel = elevatedWindowLevels[ObjectIdentifier(window)] {
                window.level = originalLevel
            }
        }
        elevatedWindowLevels.removeAll()

        if let activationPolicyBeforeUpdate {
            NSApp.setActivationPolicy(activationPolicyBeforeUpdate)
            self.activationPolicyBeforeUpdate = nil
        }
    }
}

// Sparkle calls its user-driver delegate on the main thread but does not
// annotate the protocol, hence `@preconcurrency`.
extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
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
        endSparkleUI()
    }
}
