import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// What the bar shows right now. `BarController` changes it only while the
/// panel is out of sight, so the content never resizes or swaps on screen.
@MainActor
final class BarPresentationState: ObservableObject {
    @Published var isCollapsed: Bool
    @Published var barSize: BarSize

    init(isCollapsed: Bool, barSize: BarSize) {
        self.isCollapsed = isCollapsed
        self.barSize = barSize
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
            // Fill the panel: the hosting view otherwise shrinks the window
            // to the tab, which cuts the edge of its surface.
            CollapsedTab(barSize: presentation.barSize) { settings.barCollapsed = false }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            expandedBar
        }
    }

    private var expandedBar: some View {
        ZStack {
            // Square and edge to edge: the bar meets the screen's sides
            // and edge, so no desktop shows around it.
            Color.clear
                .floatingSurface(cornerRadius: 0)

            HStack(spacing: Spacing.s) {
                if settings.showPinnedRow && !pinnedStore.pins.isEmpty {
                    PinnedRow(
                        size: presentation.barSize,
                        pinnedStore: pinnedStore,
                        runningApps: runningApps,
                        badgeStore: badgeStore
                    )
                    Divider().frame(height: presentation.barSize.chipIconSize).opacity(0.3)
                }

                WindowsRow(
                    windowStore: windowStore,
                    pinnedStore: pinnedStore,
                    badgeStore: badgeStore,
                    settings: settings,
                    size: presentation.barSize
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                CollapseBarButton(size: presentation.barSize) { settings.barCollapsed = true }
            }
            // The collapse button's system style adds its own inset, so the
            // trailing side is one step tighter to keep both visible edges equal.
            .padding(.leading, Spacing.m)
            .padding(.trailing, Spacing.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .strokeBorder(ChipStyle.accent.opacity(0.85), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFinderDrop(providers)
        }
    }

    private func handleFinderDrop(_ providers: [NSItemProvider]) -> Bool {
        let urlProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        let pinnedStore = pinnedStore
        for provider in urlProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in pinnedStore.pinAppBundle(at: url) }
            }
        }
        return !urlProviders.isEmpty
    }
}
