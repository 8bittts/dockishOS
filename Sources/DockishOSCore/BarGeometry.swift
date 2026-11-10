import CoreGraphics

/// Inputs for bar panel placement. `screenFrame` is the display; `visibleFrame`
/// excludes the menu bar and Dock. Callers map `NSScreen` and settings into
/// these values — this type does not import AppKit.
package struct BarGeometryInput: Equatable, Sendable {
    package var screenFrame: CGRect
    package var visibleFrame: CGRect
    package var collapsed: Bool
    package var barOnTop: Bool
    package var tabOnRight: Bool
    package var barHeight: CGFloat

    package init(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        collapsed: Bool,
        barOnTop: Bool,
        tabOnRight: Bool,
        barHeight: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.collapsed = collapsed
        self.barOnTop = barOnTop
        self.tabOnRight = tabOnRight
        self.barHeight = barHeight
    }
}

/// Panel frame math for the per-display bar. The SwiftUI collapsed cluster is
/// shorter than the panel by `collapsedTabHoverHeadroom`; do not use panel
/// height as the cluster size or the tab chrome will grow.
package enum BarGeometry {
    package static let collapsedTabWidth: CGFloat = 56
    package static let collapsedTabInset: CGFloat = 6
    package static let collapsedTabHoverHeadroom: CGFloat = 6
    package static let collapsedTabMinExposedHeight: CGFloat = 40
    package static let collapsedExposedHeightFactor: CGFloat = 0.78
    package static let collapsedClusterMinHeight: CGFloat = 70
    package static let collapsedClusterHeightPadding: CGFloat = 10

    package static func collapsedClusterHeight(barHeight: CGFloat) -> CGFloat {
        max(collapsedClusterMinHeight, barHeight + collapsedClusterHeightPadding)
    }

    package static func collapsedPanelHeight(barHeight: CGFloat) -> CGFloat {
        collapsedClusterHeight(barHeight: barHeight) + collapsedTabHoverHeadroom
    }

    package static func collapsedExposedHeight(barHeight: CGFloat) -> CGFloat {
        max(
            collapsedTabMinExposedHeight,
            barHeight * collapsedExposedHeightFactor
        ) + collapsedTabHoverHeadroom
    }

    package static func visibleFrame(_ input: BarGeometryInput) -> CGRect {
        if input.collapsed {
            let height = collapsedPanelHeight(barHeight: input.barHeight)
            let x = input.tabOnRight
                ? input.screenFrame.maxX - collapsedTabWidth - collapsedTabInset
                : input.screenFrame.minX + collapsedTabInset
            let exposed = collapsedExposedHeight(barHeight: input.barHeight)
            let y = input.visibleFrame.minY - (height - exposed)
            return CGRect(x: x, y: y, width: collapsedTabWidth, height: height)
        }

        let height = input.barHeight
        let y = input.barOnTop
            ? input.visibleFrame.maxY - height
            : input.visibleFrame.minY
        return CGRect(x: input.screenFrame.minX, y: y, width: input.screenFrame.width, height: height)
    }

    /// Off-screen twin of `visibleFrame`, used as the start/end of the
    /// two-phase collapse animation. The top-expanded bar slides above
    /// `screenFrame`; the collapsed tab and the bottom-expanded bar slide below it.
    package static func hiddenFrame(_ input: BarGeometryInput) -> CGRect {
        var frame = visibleFrame(input)
        let slidesUp = input.barOnTop && !input.collapsed
        frame.origin.y = slidesUp ? input.screenFrame.maxY : input.screenFrame.minY - frame.height
        return frame
    }
}
