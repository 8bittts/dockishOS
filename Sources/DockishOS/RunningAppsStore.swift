import AppKit

/// Set of bundle identifiers for currently-running apps. Replaces the
/// per-render `Set(NSWorkspace.shared.runningApplications.compactMap(...))`
/// snapshot in BarView, which executed on every SwiftUI body invalidation.
///
/// Updates on `NSWorkspace.didLaunchApplicationNotification` and
/// `didTerminateApplicationNotification`. Read from the main thread.
final class RunningAppsStore: ObservableObject {
    static let shared = RunningAppsStore()

    @Published private(set) var bundleIDs: Set<String> = []
    @Published private(set) var frontmostBundleID: String?

    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    private init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
        activationObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.frontmostBundleID = app.bundleIdentifier
            }
        }
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func contains(_ bundleID: String?) -> Bool {
        guard let bid = bundleID else { return false }
        return bundleIDs.contains(bid)
    }

    func isFrontmost(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return frontmostBundleID == bundleID
    }

    private func refresh() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if next != bundleIDs { bundleIDs = next }
    }
}
