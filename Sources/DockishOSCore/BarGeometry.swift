import CoreGraphics

/// Inputs for bar panel placement. `screenFrame` is the display; `visibleFrame`
/// excludes the menu bar and Dock. Callers map `NSScreen` and settings into
/// these values — this type does not import AppKit.
public struct BarGeometryInput: Equatable, Sendable {
    public var screenFrame: CGRect
    public var visibleFrame: CGRect
    public var collapsed: Bool
    public var barOnTop: Bool
    public var tabOnRight: Bool
    public var barHeight: CGFloat

    public init(
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
public enum BarGeometry {
    public static let collapsedTabWidth: CGFloat = 56
    public static let collapsedTabInset: CGFloat = 6
    public static let collapsedTabHoverHeadroom: CGFloat = 6
    public static let collapsedTabMinExposedHeight: CGFloat = 40
    public static let collapsedExposedHeightFactor: CGFloat = 0.78
    public static let collapsedClusterMinHeight: CGFloat = 70
    public static let collapsedClusterHeightPadding: CGFloat = 10
    public static let expandedHorizontalInset: CGFloat = 0

    public static func collapsedClusterHeight(barHeight: CGFloat) -> CGFloat {
        max(collapsedClusterMinHeight, barHeight + collapsedClusterHeightPadding)
    }

    public static func collapsedPanelHeight(barHeight: CGFloat) -> CGFloat {
        collapsedClusterHeight(barHeight: barHeight) + collapsedTabHoverHeadroom
    }

    public static func collapsedExposedHeight(barHeight: CGFloat) -> CGFloat {
        max(
            collapsedTabMinExposedHeight,
            barHeight * collapsedExposedHeightFactor
        ) + collapsedTabHoverHeadroom
    }

    public static func visibleFrame(_ input: BarGeometryInput) -> CGRect {
        if input.collapsed {
            let height = collapsedPanelHeight(barHeight: input.barHeight)
            let x: CGFloat
            if input.tabOnRight {
                x = input.screenFrame.maxX - collapsedTabWidth - collapsedTabInset
            } else {
                x = input.screenFrame.minX + collapsedTabInset
            }
            let exposed = collapsedExposedHeight(barHeight: input.barHeight)
            let y = input.visibleFrame.minY - (height - exposed)
            return CGRect(x: x, y: y, width: collapsedTabWidth, height: height)
        }

        let height = input.barHeight
        let y = input.barOnTop
            ? input.visibleFrame.maxY - height
            : input.visibleFrame.minY
        return CGRect(
            x: input.screenFrame.minX + expandedHorizontalInset,
            y: y,
            width: input.screenFrame.width - expandedHorizontalInset * 2,
            height: height
        )
    }

    /// Off-screen twin of `visibleFrame`, used as the start/end of the
    /// two-phase collapse animation. Collapsed and bottom-expanded slide
    /// below `screenFrame`; top-expanded slides above it.
    public static func hiddenFrame(_ input: BarGeometryInput) -> CGRect {
        var frame = visibleFrame(input)
        if input.collapsed {
            frame.origin.y = input.screenFrame.minY - frame.height
        } else if input.barOnTop {
            frame.origin.y = input.screenFrame.maxY
        } else {
            frame.origin.y = input.screenFrame.minY - frame.height
        }
        return frame
    }
}
