import XCTest
@testable import DockishOSCore

final class SettingsSnapshotTests: XCTestCase {
    func testSettingsSnapshotRoundTripsThroughJSON() throws {
        let snapshot = SettingsSnapshot(
            barSize: "large",
            barPosition: "top",
            showChipTitles: false,
            showPinnedRow: true,
            barCollapsed: true,
            collapsedTabPosition: .bottomLeft,
            disabledScreenUUIDs: ["display-a", "display-b"],
            groupWindowsByApp: true,
            showNotificationBadges: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }
}
