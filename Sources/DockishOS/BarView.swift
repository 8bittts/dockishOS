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
                UtilitySectionsToggle {
                    settings.barCollapsed = true
                }
            }
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ChipStyle.accent.opacity(0.85), lineWidth: 2)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
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
                    pinnedStore.pinAppBundle(at: url)
                }
            }
        }
        return accepted
    }
}
