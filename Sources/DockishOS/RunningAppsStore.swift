import AppKit

/// Bundle identifiers of the running apps and of the frontmost one, for the
/// pinned row's running dot and spoken state. Updated from `NSWorkspace`
/// launch, terminate and activate notifications.
@MainActor
final class RunningAppsStore: ObservableObject {
    static let shared = RunningAppsStore()

    @Published private(set) var bundleIDs: Set<String> = []
    @Published private(set) var frontmostBundleID: String?

    private init() {
        refresh()
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.observeOnMain(NSWorkspace.didLaunchApplicationNotification) { [weak self] _ in
            self?.refresh()
        }
        workspace.observeOnMain(NSWorkspace.didTerminateApplicationNotification) { [weak self] _ in
            self?.refresh()
        }
        workspace.observeOnMain(NSWorkspace.didActivateApplicationNotification) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let app else { return }
            self?.frontmostBundleID = app.bundleIdentifier
        }
    }

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func isFrontmost(_ bundleID: String) -> Bool {
        frontmostBundleID == bundleID
    }

    private func refresh() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if next != bundleIDs { bundleIDs = next }
    }
}
