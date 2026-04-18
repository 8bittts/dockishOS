import XCTest
@testable import DockishOSCore

final class StableIDReorderingTests: XCTestCase {
    private struct Item: Identifiable, Equatable {
        let id: String
    }

    func testMoveBySwapsAdjacentItems() {
        let items = [Item(id: "a"), Item(id: "b"), Item(id: "c")]

        let result = StableIDReordering.moving(items, itemID: "b", by: -1)

        XCTAssertEqual(result.map(\.id), ["b", "a", "c"])
    }

    func testMoveByIgnoresOutOfBoundsMoves() {
        let items = [Item(id: "a"), Item(id: "b"), Item(id: "c")]

        let result = StableIDReordering.moving(items, itemID: "a", by: -1)

        XCTAssertEqual(result.map(\.id), ["a", "b", "c"])
    }

    func testMoveOntoReinsertsBeforeTarget() {
        let items = [Item(id: "a"), Item(id: "b"), Item(id: "c"), Item(id: "d")]

        let result = StableIDReordering.moving(items, sourceID: "d", onto: "b")

        XCTAssertEqual(result.map(\.id), ["a", "d", "b", "c"])
    }

    func testMoveOntoAppendsWhenTargetDoesNotExist() {
        let items = [Item(id: "a"), Item(id: "b"), Item(id: "c")]

        let result = StableIDReordering.moving(items, sourceID: "a", onto: "missing")

        XCTAssertEqual(result.map(\.id), ["b", "c", "a"])
    }

    func testMoveOntoIgnoresSelfMove() {
        let items = [Item(id: "a"), Item(id: "b"), Item(id: "c")]

        let result = StableIDReordering.moving(items, sourceID: "b", onto: "b")

        XCTAssertEqual(result.map(\.id), ["a", "b", "c"])
    }
}
