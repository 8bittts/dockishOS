import XCTest
@testable import DockishOSCore

final class SelectionWrapTests: XCTestCase {
    func testForwardWraps() {
        XCTAssertEqual(SelectionWrap.advance(2, by: 1, count: 3), 0)
        XCTAssertEqual(SelectionWrap.advance(0, by: 1, count: 3), 1)
    }

    func testBackwardWraps() {
        XCTAssertEqual(SelectionWrap.advance(0, by: -1, count: 3), 2)
        XCTAssertEqual(SelectionWrap.advance(1, by: -1, count: 3), 0)
    }

    func testLargeDeltaIsRobust() {
        XCTAssertEqual(SelectionWrap.advance(0, by: -4, count: 3), 2)
        XCTAssertEqual(SelectionWrap.advance(0, by: 7, count: 3), 1)
    }

    func testEmptyCountReturnsIndexUnchanged() {
        XCTAssertEqual(SelectionWrap.advance(5, by: 1, count: 0), 5)
        XCTAssertEqual(SelectionWrap.advance(5, by: 1, count: -2), 5)
    }
}
