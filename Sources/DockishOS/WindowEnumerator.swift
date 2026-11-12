import AppKit
import CoreGraphics
import DockishOSCore

@MainActor
enum WindowEnumerator {
    /// On-screen, normal-layer (layer 0) windows of regular apps == the
    /// windows on the active Space that get a chip (`WindowEligibility`).
    /// No private SPI required. macOS may redact foreign-app window titles, in
    /// which case `WindowInfo.displayTitle` falls back to the owning app's name.
    static func currentSpaceWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
        let regularPIDs = Set(apps.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
        // `uniquingKeysWith` because `uniqueKeysWithValues` traps on a duplicate key.
        let bundleIDsByPID = Dictionary(
            apps.compactMap { app in
                app.bundleIdentifier.map { (app.processIdentifier, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        return list.compactMap { entry in
            guard
                let layer = entry[kCGWindowLayer as String] as? Int,
                let id = entry[kCGWindowNumber as String] as? CGWindowID,
                let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                let ownerName = entry[kCGWindowOwnerName as String] as? String,
                WindowEligibility.showsChip(
                    layer: layer,
                    alpha: entry[kCGWindowAlpha as String] as? Double ?? 1,
                    ownerIsRegularApp: regularPIDs.contains(pid),
                    ownerIsThisApp: pid == ownPID
                )
            else { return nil }
            return WindowInfo(
                id: id,
                pid: pid,
                ownerName: ownerName,
                title: entry[kCGWindowName as String] as? String ?? "",
                bundleID: bundleIDsByPID[pid]
            )
        }
    }
}
