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

    /// Short-TTL cache for the fullscreen-space-ID computation. `currentSpaceWindows()`
    /// runs on a 1s WindowStore timer (and on every app-activation notification, which can
    /// fire in bursts), and each call otherwise re-hits two CGS SPIs per display. The window
    /// set stays correct because the TTL (< the 1s poll) guarantees a fullscreen-space change
    /// is picked up within ~1s. Main-thread only, matching WindowStore's documented invariant;
    /// no locking needed.
    private static let fullscreenCacheTTL: TimeInterval = 0.75
    private static var cachedFullscreenSpaceIDs: [CGSSpaceID] = []
    private static var fullscreenCacheStamp: DispatchTime?

    private static func currentFullscreenSpaceIDs() -> [CGSSpaceID] {
        let now = DispatchTime.now()
        if let stamp = fullscreenCacheStamp {
            let age = Double(now.uptimeNanoseconds - stamp.uptimeNanoseconds) / 1_000_000_000
            if age < fullscreenCacheTTL {
                return cachedFullscreenSpaceIDs
            }
        }
        let allSpaces = SpacesAPI.allSpaces(includeFullscreen: true)
        let ids = allSpaces.compactMap { displayUUID, spaces -> CGSSpaceID? in
            let currentID = SpacesAPI.currentSpaceID(for: displayUUID)
            return spaces.first(where: { $0.id == currentID && $0.isFullscreen })?.id
        }
        cachedFullscreenSpaceIDs = ids
        fullscreenCacheStamp = now
        return ids
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
