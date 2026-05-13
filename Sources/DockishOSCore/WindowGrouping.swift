public struct WindowGroupingInput: Equatable, Sendable {
    public let id: UInt32
    public let pid: Int32
    public let ownerName: String
    public let bundleID: String?

    public init(id: UInt32, pid: Int32, ownerName: String, bundleID: String?) {
        self.id = id
        self.pid = pid
        self.ownerName = ownerName
        self.bundleID = bundleID
    }
}

public struct WindowGroupingResult: Equatable, Sendable {
    public let key: String
    public let bundleID: String?
    public let pid: Int32
    public let ownerName: String
    public let windowIDs: [UInt32]

    public init(key: String, bundleID: String?, pid: Int32, ownerName: String, windowIDs: [UInt32]) {
        self.key = key
        self.bundleID = bundleID
        self.pid = pid
        self.ownerName = ownerName
        self.windowIDs = windowIDs
    }
}

public enum WindowGrouping {
    public static func group(_ windows: [WindowGroupingInput]) -> [WindowGroupingResult] {
        var byKey: [String: [WindowGroupingInput]] = [:]
        var orderedKeys: [String] = []

        for window in windows {
            let key = window.bundleID ?? "pid:\(window.pid)"
            if byKey[key] == nil {
                orderedKeys.append(key)
            }
            byKey[key, default: []].append(window)
        }

        return orderedKeys.compactMap { key in
            guard let grouped = byKey[key], let first = grouped.first else { return nil }
            return WindowGroupingResult(
                key: key,
                bundleID: first.bundleID,
                pid: first.pid,
                ownerName: first.ownerName,
                windowIDs: grouped.map(\.id)
            )
        }
    }
}
