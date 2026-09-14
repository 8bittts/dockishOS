import XCTest
@testable import DockishOSCore

final class BoundedIndexTests: XCTestCase {
    func testMovesWithinRange() {
        XCTAssertEqual(BoundedIndex.moving(0, by: 1, count: 3), 1)
        XCTAssertEqual(BoundedIndex.moving(2, by: -1, count: 3), 1)
    }

    func testStopsAtEnds() {
        XCTAssertNil(BoundedIndex.moving(0, by: -1, count: 3))
        XCTAssertNil(BoundedIndex.moving(2, by: 1, count: 3))
    }

    func testEmptyCountIsNil() {
        XCTAssertNil(BoundedIndex.moving(0, by: 1, count: 0))
        XCTAssertNil(BoundedIndex.moving(0, by: 1, count: -1))
    }
}
