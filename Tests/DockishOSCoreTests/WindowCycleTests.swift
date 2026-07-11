import XCTest
@testable import DockishOSCore

final class WindowCycleTests: XCTestCase {
    func testEmptyReturnsNil() {
        XCTAssertNil(WindowCycle.next(ids: [], after: nil))
        XCTAssertNil(WindowCycle.next(ids: [], after: 7))
    }

    func testFirstCallStartsAtLowestID() {
        XCTAssertEqual(WindowCycle.next(ids: [30, 10, 20], after: nil), 10)
    }

    func testUnknownLastFallsBackToFirst() {
        XCTAssertEqual(WindowCycle.next(ids: [30, 10, 20], after: 999), 10)
    }

    /// The regression this fixes: repeatedly advancing must visit EVERY window
    /// exactly once per cycle, regardless of the (z-order) input ordering and
    /// even as that ordering reshuffles between calls.
    func testAdvancesThroughAllWindowsAndWraps() {
        let stable = [10, 20, 30] as [UInt32]
        var last: UInt32? = nil
        var visited: [UInt32] = []
        // Feed a DIFFERENT shuffle each call to mimic the list reordering when a
        // window is raised — the cycle must still be stable.
        let shuffles: [[UInt32]] = [[30, 10, 20], [20, 30, 10], [10, 30, 20], [30, 20, 10]]
        for i in 0..<4 {
            let next = WindowCycle.next(ids: shuffles[i], after: last)
            visited.append(next!)
            last = next
        }
        // 10 -> 20 -> 30 -> wrap to 10
        XCTAssertEqual(visited, [10, 20, 30, 10])
        XCTAssertEqual(Set(visited), Set(stable))
    }

    func testSingleWindowStaysPut() {
        XCTAssertEqual(WindowCycle.next(ids: [42], after: nil), 42)
        XCTAssertEqual(WindowCycle.next(ids: [42], after: 42), 42)
    }
}
