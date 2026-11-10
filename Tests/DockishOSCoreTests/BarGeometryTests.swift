import XCTest
@testable import DockishOSCore

final class BarGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    /// Dock 70pt, menu bar 38pt.
    private let visible = CGRect(x: 0, y: 70, width: 1440, height: 792)

    private func input(
        collapsed: Bool,
        barOnTop: Bool = false,
        tabOnRight: Bool = false,
        barHeight: CGFloat = 56
    ) -> BarGeometryInput {
        BarGeometryInput(
            screenFrame: screen,
            visibleFrame: visible,
            collapsed: collapsed,
            barOnTop: barOnTop,
            tabOnRight: tabOnRight,
            barHeight: barHeight
        )
    }

    func testExpandedBottomSitsOnVisibleMinYFullWidth() {
        let frame = BarGeometry.visibleFrame(input(collapsed: false, barHeight: 56))
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, visible.minY)
        XCTAssertEqual(frame.width, screen.width)
        XCTAssertEqual(frame.height, 56)
    }

    func testExpandedTopSitsUnderVisibleMaxY() {
        let frame = BarGeometry.visibleFrame(input(collapsed: false, barOnTop: true, barHeight: 56))
        XCTAssertEqual(frame.origin.y, visible.maxY - 56)
        XCTAssertEqual(frame.maxY, visible.maxY)
        XCTAssertEqual(frame.height, 56)
        XCTAssertEqual(frame.width, screen.width)
    }

    func testCollapsedTabHeightGrowsWithTheBar() {
        XCTAssertEqual(BarGeometry.collapsedTabHeight(barHeight: 44), 70)
        XCTAssertEqual(BarGeometry.collapsedTabHeight(barHeight: 56), 70)
        XCTAssertEqual(BarGeometry.collapsedTabHeight(barHeight: 72), 82)
    }

    func testCollapsedTabExposesPartOfItsHeight() {
        XCTAssertEqual(BarGeometry.collapsedTabExposedHeight(barHeight: 44), 40)
        XCTAssertEqual(BarGeometry.collapsedTabExposedHeight(barHeight: 72), 72 * 0.78, accuracy: 0.001)
        for barHeight: CGFloat in [44, 56, 72] {
            XCTAssertLessThan(
                BarGeometry.collapsedTabExposedHeight(barHeight: barHeight),
                BarGeometry.collapsedTabHeight(barHeight: barHeight)
            )
        }
    }

    func testCollapsedLeftIsInsetFromScreenMinX() {
        let frame = BarGeometry.visibleFrame(input(collapsed: true, tabOnRight: false, barHeight: 56))
        XCTAssertEqual(frame.origin.x, BarGeometry.collapsedTabInset)
        XCTAssertEqual(frame.width, BarGeometry.collapsedTabWidth)
        XCTAssertEqual(frame.height, BarGeometry.collapsedTabHeight(barHeight: 56))
        XCTAssertEqual(
            frame.origin.y,
            visible.minY - (frame.height - BarGeometry.collapsedTabExposedHeight(barHeight: 56)),
            accuracy: 0.001
        )
        XCTAssertGreaterThan(frame.maxY, visible.minY)
        XCTAssertLessThan(frame.minY, visible.minY)
    }

    func testCollapsedRightIsInsetFromScreenMaxX() {
        let frame = BarGeometry.visibleFrame(input(collapsed: true, tabOnRight: true, barHeight: 72))
        XCTAssertEqual(
            frame.origin.x,
            screen.maxX - BarGeometry.collapsedTabWidth - BarGeometry.collapsedTabInset
        )
        XCTAssertEqual(frame.maxX, screen.maxX - BarGeometry.collapsedTabInset)
        XCTAssertEqual(frame.height, BarGeometry.collapsedTabHeight(barHeight: 72))
    }

    func testHiddenCollapsedSitsFullyBelowScreen() {
        let hidden = BarGeometry.hiddenFrame(input(collapsed: true, barHeight: 56))
        XCTAssertEqual(hidden.maxY, screen.minY)
        XCTAssertEqual(hidden.width, BarGeometry.collapsedTabWidth)
    }

    func testHiddenExpandedBottomSitsFullyBelowScreen() {
        let hidden = BarGeometry.hiddenFrame(input(collapsed: false, barHeight: 56))
        XCTAssertEqual(hidden.maxY, screen.minY)
        XCTAssertEqual(hidden.height, 56)
        XCTAssertEqual(hidden.width, screen.width)
    }

    func testHiddenExpandedTopSitsFullyAboveScreen() {
        let hidden = BarGeometry.hiddenFrame(input(collapsed: false, barOnTop: true, barHeight: 56))
        XCTAssertEqual(hidden.minY, screen.maxY)
        XCTAssertEqual(hidden.height, 56)
    }
}
