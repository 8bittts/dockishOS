import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
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

    /// Room kept clear on the trailing edge for the collapse button.
    private static let collapseButtonReservation: CGFloat = 88
    private static let cornerRadius: CGFloat = 16

    var body: some View {
        if presentation.isCollapsed {
            CollapsedTab(barSize: settings.barSize) { settings.barCollapsed = false }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        } else {
            expandedBar
        }
    }

    private var expandedBar: some View {
        ZStack {
            Color.clear
                .floatingSurface(cornerRadius: Self.cornerRadius)
                .padding(.vertical, 6)

            HStack(spacing: 8) {
                if settings.showPinnedRow && !pinnedStore.pins.isEmpty {
                    PinnedRow(
                        size: settings.barSize,
                        pinnedStore: pinnedStore,
                        runningApps: runningApps,
                        badgeStore: badgeStore
                    )
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
            .padding(.leading, 18)
            .padding(.trailing, Self.collapseButtonReservation)

            HStack {
                Spacer(minLength: 0)
                CollapseBarButton { settings.barCollapsed = true }
            }
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(ChipStyle.accent.opacity(0.85), lineWidth: 2)
                    .padding(.vertical, 6)
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
