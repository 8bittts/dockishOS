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

/// Panel frame math for the per-display bar and its collapsed edge tab.
package enum BarGeometry {
    package static let collapsedTabWidth: CGFloat = 56
    /// Gap between the edge tab's panel and the side of the screen. The tab's
    /// surface sits 4 points further in, so it stands 12 points off the edge.
    package static let collapsedTabInset: CGFloat = 8
    /// Tallest gap under `visibleFrame` that is an auto-hidden Dock's
    /// reveal strip rather than a Dock on screen.
    package static let hiddenDockStripLimit: CGFloat = 8

    /// Bottom edge the bar and the edge tab rest on. It is the visible
    /// frame's, unless the only thing below that is an auto-hidden Dock's
    /// reveal strip: then it is the screen's, so no desktop shows under the bar.
    package static func bottomEdge(_ input: BarGeometryInput) -> CGFloat {
        let gap = input.visibleFrame.minY - input.screenFrame.minY
        return gap <= hiddenDockStripLimit ? input.screenFrame.minY : input.visibleFrame.minY
    }

    /// Height of the edge tab. Only `collapsedTabExposedHeight` of it shows;
    /// the rest sits below the visible frame, so the tab reads as attached
    /// to the bottom edge.
    package static func collapsedTabHeight(barHeight: CGFloat) -> CGFloat {
        max(70, barHeight + 10)
    }

    /// How much of the edge tab shows above the bottom edge: about four
    /// fifths of the bar, on the 4-point grid so the icon lands on whole points.
    package static func collapsedTabExposedHeight(barHeight: CGFloat) -> CGFloat {
        max(40, (barHeight * 0.78 / 4).rounded() * 4)
    }

    package static func visibleFrame(_ input: BarGeometryInput) -> CGRect {
        if input.collapsed {
            let height = collapsedTabHeight(barHeight: input.barHeight)
            let x = input.tabOnRight
                ? input.screenFrame.maxX - collapsedTabWidth - collapsedTabInset
                : input.screenFrame.minX + collapsedTabInset
            let exposed = collapsedTabExposedHeight(barHeight: input.barHeight)
            let y = bottomEdge(input) - (height - exposed)
            return CGRect(x: x, y: y, width: collapsedTabWidth, height: height)
        }

        let height = input.barHeight
        let y = input.barOnTop
            ? input.visibleFrame.maxY - height
            : bottomEdge(input)
        return CGRect(x: input.screenFrame.minX, y: y, width: input.screenFrame.width, height: height)
    }

    /// How a surface leaves and enters the screen. A surface on the bottom
    /// edge (the bottom bar, the edge tab) slides through that edge; the top
    /// bar fades in place, because sliding it would cross the menu bar.
    /// Reduce Motion turns every slide into a fade.
    package static func transition(_ input: BarGeometryInput, reduceMotion: Bool) -> BarTransition {
        let onTopEdge = input.barOnTop && !input.collapsed
        return onTopEdge || reduceMotion ? .fade : .slide
    }

    /// Where a sliding surface starts and ends: `visibleFrame` moved just
    /// below the screen's bottom edge.
    package static func hiddenFrame(_ input: BarGeometryInput) -> CGRect {
        var frame = visibleFrame(input)
        frame.origin.y = input.screenFrame.minY - frame.height
        return frame
    }
}

/// The two motions a bar surface uses to leave or enter the screen.
package enum BarTransition: Equatable, Sendable {
    case slide
    case fade
}
