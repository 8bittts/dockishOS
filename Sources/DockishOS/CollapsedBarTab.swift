import SwiftUI
import AppKit
import DockishOSCore

/// The edge tab a collapsed bar leaves behind. Click it to expand the bar.
struct CollapsedTab: View {
    let barSize: BarSize
    let action: () -> Void

    /// Room on each side so the surface's edge is not cut by the panel.
    private static let horizontalInset = Spacing.xs

    var body: some View {
        Button(action: action) {
            BrandMark(size: barSize.controlIconSize)
                // Center the icon in the part of the tab that shows.
                .frame(
                    width: BarGeometry.collapsedTabWidth - Self.horizontalInset * 2,
                    height: BarGeometry.collapsedTabExposedHeight(barHeight: barSize.height)
                )
                .frame(height: BarGeometry.collapsedTabHeight(barHeight: barSize.height), alignment: .top)
                .floatingSurface(cornerRadius: Radius.control)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Expand bar")
        .accessibilityLabel("Expand bar")
    }
}

/// Collapse control on the trailing edge of the expanded bar. It scales
/// with the bar: the chevron with the chip titles, the mark with `controlIconSize`.
struct CollapseBarButton: View {
    let size: BarSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chevron.down")
                    .font(size.chipTitleFont.weight(.semibold))
                BrandMark(size: size.controlIconSize)
            }
        }
        .buttonStyle(.accessoryBar)
        .help("Collapse bar into edge tab")
        .accessibilityLabel("Collapse bar")
    }
}

/// The app's icon as macOS renders it, drawn at `size` points.
private struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: DockishBrandAssets.applicationIcon(size: NSSize(width: size, height: size)))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
