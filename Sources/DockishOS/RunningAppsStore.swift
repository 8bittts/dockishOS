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

    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

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
    }

    func contains(_ bundleID: String?) -> Bool {
        guard let bid = bundleID else { return false }
        return bundleIDs.contains(bid)
    }

    private func refresh() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if next != bundleIDs { bundleIDs = next }
    }
}
