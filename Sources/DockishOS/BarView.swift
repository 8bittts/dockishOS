import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Top-level layout for one bar (one per screen). Composes:
///
///     [SpacesRow] | [PinnedRow]? | [WindowsRow]
///
/// Accepts a `.fileURL` drop anywhere on the bar so the user can drag
/// `.app` bundles from Finder to pin them.
struct BarView: View {
    let screen: NSScreen
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var spacesStore: SpacesStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var badgeStore: BadgeStore
    @ObservedObject var runningApps: RunningAppsStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 8) {
                SpacesRow(
                    size: settings.barSize,
                    spaces: spacesStore.spaces(for: screen),
                    currentID: spacesStore.currentSpaceID(for: screen),
                    onPick: { spacesStore.switchTo($0) }
                )

                if settings.showPinnedRow {
                    Divider().frame(height: 24).opacity(0.3)
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

                Divider().frame(height: 24).opacity(0.3)

                WindowsRow(
                    windowStore: windowStore,
                    pinnedStore: pinnedStore,
                    badgeStore: badgeStore,
                    settings: settings
                )
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFinderDrop(providers)
        }
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
