import AppKit
import CoreGraphics

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let ownerName: String
    let title: String
    let bundleID: String?

    var displayTitle: String { title.isEmpty ? ownerName : title }
}

enum WindowEnumerator {
    /// On-screen, normal-layer (layer 0) windows == windows on the active Space.
    /// No private SPI required. macOS may redact foreign-app window titles, in
    /// which case we fall back to the owning app's name.
    static func currentSpaceWindows() -> [WindowInfo] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let myPid = ProcessInfo.processInfo.processIdentifier
        // `Dictionary(uniqueKeysWithValues:)` traps on duplicate keys.
        // PIDs are unique in practice but `Dictionary(_:uniquingKeysWith:)`
        // is the safe equivalent.
        let runningByPid: [pid_t: NSRunningApplication] = Dictionary(
            NSWorkspace.shared.runningApplications.compactMap {
                $0.processIdentifier > 0 ? ($0.processIdentifier, $0) : nil
            },
            uniquingKeysWith: { first, _ in first }
        )
        var windows = raw.compactMap { dict -> WindowInfo? in
            guard
                let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                let window = windowInfo(from: dict, runningByPid: runningByPid, excludingPID: myPid)
            else { return nil }
            return window
        }
        supplementFullscreenWindows(into: &windows, runningByPid: runningByPid, excludingPID: myPid)
        return windows
    }

    private static func supplementFullscreenWindows(
        into windows: inout [WindowInfo],
        runningByPid: [pid_t: NSRunningApplication],
        excludingPID myPid: pid_t
    ) {
        let fullscreenSpaceIDs = currentFullscreenSpaceIDs()
        guard !fullscreenSpaceIDs.isEmpty else { return }

        var seen = Set(windows.map(\.id))
        for spaceID in fullscreenSpaceIDs {
            for windowID in SpacesAPI.windowIDs(for: spaceID) where !seen.contains(windowID) {
                guard
                    let raw = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
                    let dict = raw.first,
                    let window = windowInfo(from: dict, runningByPid: runningByPid, excludingPID: myPid)
                else { continue }
                seen.insert(window.id)
                windows.append(window)
            }
        }
    }

    private static func currentFullscreenSpaceIDs() -> [CGSSpaceID] {
        let allSpaces = SpacesAPI.allSpaces(includeFullscreen: true)
        return allSpaces.compactMap { displayUUID, spaces in
            let currentID = SpacesAPI.currentSpaceID(for: displayUUID)
            return spaces.first(where: { $0.id == currentID && $0.isFullscreen })?.id
        }
    }

    private static func windowInfo(
        from dict: [String: Any],
        runningByPid: [pid_t: NSRunningApplication],
        excludingPID myPid: pid_t
    ) -> WindowInfo? {
        guard
            let id = dict[kCGWindowNumber as String] as? CGWindowID,
            let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
            let owner = dict[kCGWindowOwnerName as String] as? String,
            pid != myPid
        else { return nil }
        let title = dict[kCGWindowName as String] as? String ?? ""
        let bundleID = runningByPid[pid]?.bundleIdentifier
        return WindowInfo(id: id, pid: pid, ownerName: owner, title: title, bundleID: bundleID)
    }
}
