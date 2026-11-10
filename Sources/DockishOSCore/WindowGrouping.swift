/// One window as the window server lists it. `id` is its `CGWindowID` and
/// `pid` its owner's process identifier.
package struct WindowInfo: Identifiable, Hashable, Sendable {
    package let id: UInt32
    package let pid: Int32
    package let ownerName: String
    package let title: String
    package let bundleID: String?

    package init(id: UInt32, pid: Int32, ownerName: String, title: String, bundleID: String?) {
        self.id = id
        self.pid = pid
        self.ownerName = ownerName
        self.title = title
        self.bundleID = bundleID
    }

    /// The window's title, or its app's name when the title is empty or redacted.
    package var displayTitle: String { title.isEmpty ? ownerName : title }
}

/// The windows of one app, for the "group windows by app" bar mode.
package struct AppWindowGroup: Identifiable, Equatable, Sendable {
    /// The app's bundle ID, or `pid:<pid>` for a process that has none.
    package let id: String
    package let bundleID: String?
    package let pid: Int32
    package let ownerName: String
    package let windows: [WindowInfo]
}

package enum WindowGrouping {
    /// Groups windows by app. Groups keep the order in which their first
    /// window appears, and windows keep their order inside each group.
    package static func group(_ windows: [WindowInfo]) -> [AppWindowGroup] {
        var windowsByID: [String: [WindowInfo]] = [:]
        var orderedIDs: [String] = []

        for window in windows {
            let id = window.bundleID ?? "pid:\(window.pid)"
            if windowsByID[id] == nil {
                orderedIDs.append(id)
            }
            windowsByID[id, default: []].append(window)
        }

        return orderedIDs.compactMap { id in
            guard let grouped = windowsByID[id], let first = grouped.first else { return nil }
            return AppWindowGroup(
                id: id,
                bundleID: first.bundleID,
                pid: first.pid,
                ownerName: first.ownerName,
                windows: grouped
            )
        }
    }
}
