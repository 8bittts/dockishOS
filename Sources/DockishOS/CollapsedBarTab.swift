import SwiftUI
import AppKit
import DockishOSCore

/// The edge tab a collapsed bar leaves behind. Click it to expand the bar.
struct CollapsedTab: View {
    let barSize: BarSize
    let action: () -> Void

    private static let iconSize: CGFloat = 18
    /// Room on each side so the surface's edge is not cut by the panel.
    private static let horizontalInset: CGFloat = 6
    private let icon = DockishBrandAssets.applicationIcon(size: NSSize(width: iconSize, height: iconSize))

    var body: some View {
        Button(action: action) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)
                // Center the icon in the part of the tab that shows.
                .frame(
                    width: BarGeometry.collapsedTabWidth - Self.horizontalInset * 2,
                    height: BarGeometry.collapsedTabExposedHeight(barHeight: barSize.height)
                )
                .frame(height: BarGeometry.collapsedTabHeight(barHeight: barSize.height), alignment: .top)
                .floatingSurface(cornerRadius: 14, interactive: true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Expand bar")
        .accessibilityLabel("Expand bar")
    }
}

/// Collapse control on the trailing edge of the expanded bar.
struct CollapseBarButton: View {
    let action: () -> Void
    /// Sized to sit just under the chip label rather than dominating it.
    private static let iconSize: CGFloat = 13
    private let logo = DockishBrandAssets.applicationIcon(
        size: NSSize(width: iconSize, height: iconSize)
    )

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))

                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
        }
        .buttonStyle(.accessoryBar)
        .help("Collapse bar into edge tab")
        .accessibilityLabel("Collapse bar")
    }
}
