import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class BarPresentationState: ObservableObject {
    @Published var isCollapsed: Bool

    init(isCollapsed: Bool) {
        self.isCollapsed = isCollapsed
    }
}

/// Top-level layout for one bar (one per screen). Composes:
///
///     [PinnedRow]? | [WindowsRow]
///
/// Accepts a `.fileURL` drop anywhere on the bar so the user can drag
/// `.app` bundles from Finder to pin them.
struct BarView: View {
    let screen: NSScreen
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var badgeStore: BadgeStore
    @ObservedObject var runningApps: RunningAppsStore
    @ObservedObject var settings: SettingsStore
    @ObservedObject var presentation: BarPresentationState
    @State private var isDropTargeted = false

    var body: some View {
        if presentation.isCollapsed {
            collapsedTab
        } else {
            expandedBar
        }
    }

    private var expandedBar: some View {
        let showPinned = settings.showPinnedRow && !pinnedStore.pins.isEmpty
        let collapseControlReservation: CGFloat = 88

        return ZStack {
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 8) {
                if showPinned {
                    PinnedRow(
                        size: settings.barSize,
                        pins: pinnedStore.pins,
                        runningApps: runningApps,
                        badgeStore: badgeStore,
                        onLaunch:  { pinnedStore.launch($0) },
                        onUnpin:   { pinnedStore.unpin(bundleID: $0.bundleID) },
                        onMove:    { pinnedStore.move($0, by: $1) },
                        onReorder: { src, dst in pinnedStore.move(sourceID: src, onto: dst) }
                    )
                }

                if showPinned {
                    Divider().frame(height: 24).opacity(0.3)
                }

                WindowsRow(
                    windowStore: windowStore,
                    pinnedStore: pinnedStore,
                    badgeStore: badgeStore,
                    settings: settings
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 12)
            .padding(.trailing, collapseControlReservation)

            HStack {
                Spacer(minLength: 0)
                UtilitySectionsToggle(
                    collapsed: false,
                    action: {
                        settings.barCollapsed = true
                    }
                )
            }
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFinderDrop(providers)
        }
    }

    private var collapsedTab: some View {
        let metrics = CollapsedTabMetrics(
            barSize: settings.barSize
        )

        return CollapsedTabCluster(metrics: metrics, action: { settings.barCollapsed = false })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func handleFinderDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    PinnedAppsStore.shared.pinAppBundle(at: url)
                }
            }
        }
        return accepted
    }
}

private struct CollapsedTabMetrics {
    let barSize: BarSize

    var containerAlignment: Alignment {
        .center
    }

    var backgroundVerticalPadding: CGFloat {
        0
    }

    var clusterWidth: CGFloat {
        56
    }

    var clusterHeight: CGFloat {
        max(70, barSize.height + 10)
    }

    var backgroundCornerRadius: CGFloat {
        14
    }

    var backgroundFillOpacity: Double {
        0.76
    }

    var backgroundStrokeOpacity: Double {
        0.10
    }

    var backgroundHighlightOpacity: Double {
        0.08
    }

    var backgroundShadowOpacity: Double {
        0.14
    }

    var backgroundShadowRadius: CGFloat {
        8
    }

    var backgroundShadowY: CGFloat {
        2
    }

    var buttonTopPadding: CGFloat {
        10
    }

    var buttonBottomPadding: CGFloat {
        10
    }

    var buttonWidth: CGFloat {
        42
    }

    var buttonHeight: CGFloat {
        50
    }

    var buttonCornerRadius: CGFloat {
        14
    }

    var iconOffsetY: CGFloat {
        -7
    }
}

private struct CollapsedTabBackdrop: View {
    let metrics: CollapsedTabMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: metrics.backgroundCornerRadius, style: .continuous)
            .fill(Color.black.opacity(metrics.backgroundFillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: metrics.backgroundCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(metrics.backgroundStrokeOpacity), lineWidth: 0.55)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: metrics.backgroundCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(metrics.backgroundHighlightOpacity),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: 16)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.backgroundCornerRadius, style: .continuous))
            }
            .shadow(
                color: .black.opacity(metrics.backgroundShadowOpacity),
                radius: metrics.backgroundShadowRadius,
                y: metrics.backgroundShadowY
            )
    }
}

private struct CollapsedTabCluster: View {
    let metrics: CollapsedTabMetrics
    let action: () -> Void
    @State private var hover = false
    @State private var sheenPhase: CGFloat = -1.2

    var body: some View {
        ZStack(alignment: metrics.containerAlignment) {
            CollapsedTabBackdrop(metrics: metrics)
                .padding(.vertical, metrics.backgroundVerticalPadding)

            CollapsedBarTab(
                metrics: metrics,
                hover: hover,
                sheenPhase: sheenPhase,
                action: action
            )
            .padding(.top, metrics.buttonTopPadding)
            .padding(.bottom, metrics.buttonBottomPadding)
        }
        .frame(
            width: metrics.clusterWidth,
            height: metrics.clusterHeight,
            alignment: metrics.containerAlignment
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .task {
            sheenPhase = -1.2
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.35)) {
                    sheenPhase = 1.2
                }
                try? await Task.sleep(nanoseconds: 1_350_000_000)
                if Task.isCancelled { break }
                sheenPhase = -1.2
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
        .onDisappear {
            withAnimation(.none) {
                sheenPhase = -1.2
            }
        }
        .help("Expand bar")
        .accessibilityLabel("Expand bar")
    }
}

private struct CollapsedBarTab: View {
    let metrics: CollapsedTabMetrics
    let hover: Bool
    let sheenPhase: CGFloat
    let action: () -> Void

    private let icon = DockishBrandAssets.applicationIcon(size: NSSize(width: 18, height: 18))
    private let iconSize: CGFloat = 18

    private var iconImage: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: iconSize, height: iconSize)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    iconImage

                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.54, height: proxy.size.height * 1.65)
                        .rotationEffect(.degrees(18))
                        .offset(x: proxy.size.width * sheenPhase)
                        .blendMode(.screen)
                        .mask(iconImage)
                    }
                    .frame(width: iconSize, height: iconSize)
                    .allowsHitTesting(false)
                }
                    .offset(y: metrics.iconOffsetY)
            }
            .frame(width: metrics.buttonWidth, height: metrics.buttonHeight)
            .background(buttonChrome)
        }
        .buttonStyle(.plain)
    }

    private var buttonChrome: some View {
        RoundedRectangle(cornerRadius: metrics.buttonCornerRadius, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(hover ? 0.985 : 0.96))
            .overlay {
                RoundedRectangle(cornerRadius: metrics.buttonCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(hover ? 0.13 : 0.08), lineWidth: 0.55)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: metrics.buttonCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(hover ? 0.34 : 0.26),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.buttonCornerRadius, style: .continuous))
            }
            .shadow(
                color: .black.opacity(0.10),
                radius: 6,
                y: 2
            )
    }
}

private struct UtilitySectionsToggle: View {
    let collapsed: Bool
    let action: () -> Void
    @State private var hover = false
    private let logo = DockishBrandAssets.applicationIcon(size: NSSize(width: 16, height: 16))

    var body: some View {
        Button(action: action) {
            HStack(spacing: collapsed ? 0 : 7) {
                Image(systemName: collapsed ? "chevron.left" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if !collapsed {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: collapsed ? 44 : 68, height: collapsed ? 44 : 34)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(buttonChrome)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.10), value: hover)
        .help(collapsed ? "Expand bar" : "Collapse bar into edge tab")
        .accessibilityLabel(collapsed ? "Expand bar" : "Collapse bar")
    }

    private var buttonChrome: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(hover ? 0.88 : 0.42))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(hover ? 0.34 : 0.12), lineWidth: 0.8)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(hover ? 0.28 : 0.12),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
    }
}
