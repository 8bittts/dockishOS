import XCTest
@testable import DockishOSCore

final class WindowGroupingTests: XCTestCase {
    func testGroupsWindowsByBundleIDAndPreservesFirstSeenGroupOrder() {
        let windows = [
            WindowGroupingInput(id: 1, pid: 100, ownerName: "Notes", bundleID: "com.apple.Notes"),
            WindowGroupingInput(id: 2, pid: 200, ownerName: "Safari", bundleID: "com.apple.Safari"),
            WindowGroupingInput(id: 3, pid: 100, ownerName: "Notes", bundleID: "com.apple.Notes"),
        ]

        let groups = WindowGrouping.group(windows)

        XCTAssertEqual(groups.map(\.key), ["com.apple.Notes", "com.apple.Safari"])
        XCTAssertEqual(groups[0].windowIDs, [1, 3])
        XCTAssertEqual(groups[1].windowIDs, [2])
    }

    func testGroupsWindowsWithoutBundleIDByPID() {
        let windows = [
            WindowGroupingInput(id: 10, pid: 42, ownerName: "Untitled", bundleID: nil),
            WindowGroupingInput(id: 11, pid: 42, ownerName: "Untitled", bundleID: nil),
        ]

        let groups = WindowGrouping.group(windows)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].key, "pid:42")
        XCTAssertEqual(groups[0].windowIDs, [10, 11])
    }
}
