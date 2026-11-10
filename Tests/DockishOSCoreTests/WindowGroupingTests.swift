import XCTest
@testable import DockishOSCore

final class WindowGroupingTests: XCTestCase {
    private func window(_ id: UInt32, pid: Int32, owner: String, bundleID: String?) -> WindowInfo {
        WindowInfo(id: id, pid: pid, ownerName: owner, title: "", bundleID: bundleID)
    }

    func testGroupsWindowsByBundleIDAndPreservesFirstSeenGroupOrder() {
        let groups = WindowGrouping.group([
            window(1, pid: 100, owner: "Notes", bundleID: "com.apple.Notes"),
            window(2, pid: 200, owner: "Safari", bundleID: "com.apple.Safari"),
            window(3, pid: 100, owner: "Notes", bundleID: "com.apple.Notes"),
        ])

        XCTAssertEqual(groups.map(\.id), ["com.apple.Notes", "com.apple.Safari"])
        XCTAssertEqual(groups[0].windows.map(\.id), [1, 3])
        XCTAssertEqual(groups[1].windows.map(\.id), [2])
        XCTAssertEqual(groups[1].ownerName, "Safari")
        XCTAssertEqual(groups[1].pid, 200)
    }

    func testGroupsWindowsWithoutBundleIDByPID() {
        let groups = WindowGrouping.group([
            window(10, pid: 42, owner: "Helper", bundleID: nil),
            window(11, pid: 42, owner: "Helper", bundleID: nil),
        ])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].id, "pid:42")
        XCTAssertNil(groups[0].bundleID)
        XCTAssertEqual(groups[0].windows.map(\.id), [10, 11])
    }

    func testDisplayTitleFallsBackToOwnerName() {
        XCTAssertEqual(window(1, pid: 1, owner: "Notes", bundleID: nil).displayTitle, "Notes")
        XCTAssertEqual(
            WindowInfo(id: 1, pid: 1, ownerName: "Notes", title: "Groceries", bundleID: nil).displayTitle,
            "Groceries"
        )
    }
}
