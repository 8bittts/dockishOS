import XCTest
@testable import DockishOSCore

final class CollapsedTabPlacementTests: XCTestCase {
    func testPersistedPlacementMigratesLegacyTopNamesToBottomEdges() {
        XCTAssertEqual(CollapsedTabPlacement(persistedRawValue: "topLeft"), .bottomLeft)
        XCTAssertEqual(CollapsedTabPlacement(persistedRawValue: "topRight"), .bottomRight)
    }

    func testPersistedPlacementDefaultsToBottomRight() {
        XCTAssertEqual(CollapsedTabPlacement(persistedRawValue: nil), .bottomRight)
        XCTAssertEqual(CollapsedTabPlacement(persistedRawValue: "unknown"), .bottomRight)
    }
}
