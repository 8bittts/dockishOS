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
        barHeight: CGFloat = 56,
        visibleFrame: CGRect? = nil
    ) -> BarGeometryInput {
        BarGeometryInput(
            screenFrame: screen,
            visibleFrame: visibleFrame ?? visible,
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
        XCTAssertEqual(BarGeometry.collapsedTabExposedHeight(barHeight: 56), 44)
        XCTAssertEqual(BarGeometry.collapsedTabExposedHeight(barHeight: 72), 56)
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

    func testTopBarFadesAndBottomSurfacesSlide() {
        XCTAssertEqual(BarGeometry.transition(input(collapsed: false, barOnTop: true), reduceMotion: false), .fade)
        XCTAssertEqual(BarGeometry.transition(input(collapsed: false, barOnTop: false), reduceMotion: false), .slide)
        // The edge tab is always on the bottom edge, even for a top bar.
        XCTAssertEqual(BarGeometry.transition(input(collapsed: true, barOnTop: true), reduceMotion: false), .slide)
        XCTAssertEqual(BarGeometry.transition(input(collapsed: true, barOnTop: false), reduceMotion: false), .slide)
    }

    func testReduceMotionFadesEverySurface() {
        for collapsed in [false, true] {
            for barOnTop in [false, true] {
                XCTAssertEqual(
                    BarGeometry.transition(input(collapsed: collapsed, barOnTop: barOnTop), reduceMotion: true),
                    .fade
                )
            }
        }
    }

    /// An auto-hidden bottom Dock reserves a thin strip under the visible
    /// frame; the bar covers it so no desktop shows below the bar.
    func testExpandedBottomCoversAHiddenDockStrip() {
        let hiddenDock = CGRect(x: 0, y: 4, width: 1440, height: 858)
        let frame = BarGeometry.visibleFrame(input(collapsed: false, visibleFrame: hiddenDock))
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.minX, screen.minX)
        XCTAssertEqual(frame.maxX, screen.maxX)
        XCTAssertEqual(frame.height, 56)
    }

    func testExpandedBottomMeetsTheScreenEdgeWithNoBottomDock() {
        let leftDock = CGRect(x: 70, y: 0, width: 1370, height: 862)
        let frame = BarGeometry.visibleFrame(input(collapsed: false, visibleFrame: leftDock))
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width)
    }

    func testCollapsedTabRestsOnTheScreenEdgeOverAHiddenDockStrip() {
        let hiddenDock = CGRect(x: 0, y: 4, width: 1440, height: 858)
        let frame = BarGeometry.visibleFrame(input(collapsed: true, visibleFrame: hiddenDock))
        XCTAssertEqual(frame.maxY, screen.minY + BarGeometry.collapsedTabExposedHeight(barHeight: 56), accuracy: 0.001)
    }
}
