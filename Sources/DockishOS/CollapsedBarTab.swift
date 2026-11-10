import SwiftUI
import AppKit
import DockishOSCore

/// The edge tab a collapsed bar leaves behind. Click it to expand the bar.
struct CollapsedTab: View {
    let barSize: BarSize
    let action: () -> Void
    @State private var hover = false
    @State private var sheenPhase = Self.sheenStart
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The sheen band's horizontal offset, in icon widths, before and after a sweep.
    private static let sheenStart: CGFloat = -1.2
    private static let sheenEnd: CGFloat = 1.2
    private static let sheenSweep: Duration = .milliseconds(1350)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // The panel is taller than the cluster by the hover headroom.
                Color.clear.frame(
                    width: BarGeometry.collapsedTabWidth,
                    height: BarGeometry.collapsedPanelHeight(barHeight: barSize.height)
                )

                ZStack {
                    CollapsedTabBackdrop()
                    CollapsedTabButton(hover: hover, sheenPhase: sheenPhase)
                        .padding(.vertical, 10)
                }
                .frame(
                    width: BarGeometry.collapsedTabWidth,
                    height: BarGeometry.collapsedClusterHeight(barHeight: barSize.height)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(ChipStyle.hoverAnimation, value: hover)
        .task(id: reduceMotion) {
            sheenPhase = Self.sheenStart
            guard !reduceMotion else { return }
            try? await runSheen()
        }
        .help("Expand bar")
        .accessibilityLabel("Expand bar")
    }

    /// Sweeps a highlight across the icon now and then. Ends when the task is
    /// cancelled, which makes the pending sleep throw.
    private func runSheen() async throws {
        try await Task.sleep(for: .seconds(2))
        while true {
            withAnimation(.easeInOut(duration: 1.35)) {
                sheenPhase = Self.sheenEnd
            }
            try await Task.sleep(for: Self.sheenSweep)
            sheenPhase = Self.sheenStart
            try await Task.sleep(for: .seconds(8))
        }
    }
}

/// Collapse control on the trailing edge of the expanded bar.
struct CollapseBarButton: View {
    let action: () -> Void
    @State private var hover = false
    /// Sized to sit just under the 12pt chip label rather than dominating it.
    private static let iconSize: CGFloat = 13
    private static let hoverWashOpacity: Double = 0.08
    private let logo = DockishBrandAssets.applicationIcon(
        size: NSSize(width: iconSize, height: iconSize)
    )

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)

                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
            .frame(width: 60, height: 34)
            .contentShape(RoundedRectangle(cornerRadius: ChipStyle.cornerRadius, style: .continuous))
            .background(buttonChrome)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(ChipStyle.hoverAnimation, value: hover)
        .help("Collapse bar into edge tab")
        .accessibilityLabel("Collapse bar")
    }

    /// Chromeless by default. The control reads as part of the bar, so it
    /// carries no outline, fill, or top highlight. Hover uses a neutral wash
    /// rather than `ChipStyle.hoverFill` because this control sits on the bar
    /// surface itself, not among the accent-tinted chips.
    private var buttonChrome: some View {
        RoundedRectangle(cornerRadius: ChipStyle.cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(hover ? Self.hoverWashOpacity : 0))
    }
}

/// Corner radius shared by the collapsed tab's backdrop and its button.
private let collapsedTabCornerRadius: CGFloat = 14

/// Rounded surface with a hairline border, a soft top highlight and a shadow.
private struct CollapsedTabSurface: View {
    let fillOpacity: Double
    let strokeOpacity: Double
    let highlightOpacity: Double
    let highlightHeight: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: collapsedTabCornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(Color(nsColor: .windowBackgroundColor).opacity(fillOpacity))
            .overlay {
                shape.stroke(Color(nsColor: .separatorColor).opacity(strokeOpacity), lineWidth: 0.55)
            }
            .overlay(alignment: .top) {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .highlightColor).opacity(highlightOpacity),
                                Color(nsColor: .highlightColor).opacity(0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: highlightHeight)
                    .clipShape(shape)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: 2)
    }
}

private struct CollapsedTabBackdrop: View {
    var body: some View {
        CollapsedTabSurface(
            fillOpacity: 0.76,
            strokeOpacity: 0.10,
            highlightOpacity: 0.08,
            highlightHeight: 16,
            shadowOpacity: 0.14,
            shadowRadius: 8
        )
    }
}

private struct CollapsedTabButton: View {
    let hover: Bool
    let sheenPhase: CGFloat

    private static let iconSize: CGFloat = 18
    private let icon = DockishBrandAssets.applicationIcon(size: NSSize(width: iconSize, height: iconSize))

    private var iconImage: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: Self.iconSize, height: Self.iconSize)
    }

    var body: some View {
        ZStack {
            iconImage

            GeometryReader { proxy in
                LinearGradient(
                    colors: [0, 0, 0.24, 0, 0].map { Color(nsColor: .highlightColor).opacity($0) },
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width * 0.54, height: proxy.size.height * 1.65)
                .rotationEffect(.degrees(18))
                .offset(x: proxy.size.width * sheenPhase)
                .blendMode(.screen)
                .mask(iconImage)
            }
            .frame(width: Self.iconSize, height: Self.iconSize)
            .allowsHitTesting(false)
        }
        .offset(y: -7)
        .frame(width: 42, height: 50)
        .background(
            CollapsedTabSurface(
                fillOpacity: hover ? 0.985 : 0.96,
                strokeOpacity: hover ? 0.55 : 0.35,
                highlightOpacity: hover ? 0.34 : 0.26,
                highlightHeight: 18,
                shadowOpacity: 0.10,
                shadowRadius: 6
            )
        )
    }
}
