import XCTest
@testable import DockishOSCore

final class DisplayNameDisambiguatorTests: XCTestCase {
    private func item(_ id: String, _ name: String) -> DisplayNameDisambiguator.Item {
        DisplayNameDisambiguator.Item(id: id, name: name)
    }

    func testNoCollisionLeavesNamesUnchanged() {
        let input = [item("a", "Built-in"), item("b", "Studio Display")]
        XCTAssertEqual(DisplayNameDisambiguator.disambiguate(input), input)
    }

    func testTwoWayCollisionSuffixesInOrder() {
        let out = DisplayNameDisambiguator.disambiguate([
            item("a", "Studio Display"),
            item("b", "Studio Display"),
        ])
        XCTAssertEqual(out.map(\.name), ["Studio Display 1", "Studio Display 2"])
        XCTAssertEqual(out.map(\.id), ["a", "b"])
    }

    func testThreeWayCollisionAndMixed() {
        let out = DisplayNameDisambiguator.disambiguate([
            item("a", "Dell"),
            item("b", "Studio Display"),
            item("c", "Dell"),
            item("d", "Dell"),
        ])
        XCTAssertEqual(out.map(\.name), ["Dell 1", "Studio Display", "Dell 2", "Dell 3"])
    }

    func testEmpty() {
        XCTAssertTrue(DisplayNameDisambiguator.disambiguate([]).isEmpty)
    }
}
