import SwiftUI
import AppKit

/// Persistent row of pinned apps. Click to launch / activate, drag to
/// reorder, right-click for unpin / move.
struct PinnedRow: View {
    let size: BarSize
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var runningApps: RunningAppsStore
    @ObservedObject var badgeStore: BadgeStore

    var body: some View {
        let pins = pinnedStore.pins
        HStack(spacing: 4) {
            ForEach(pins) { app in
                PinnedChip(
                    app: app,
                    size: size,
                    isRunning: runningApps.contains(app.bundleID),
                    isFrontmost: runningApps.isFrontmost(app.bundleID),
                    badge: badgeStore.badge(for: app.bundleID),
                    isFirst: app == pins.first,
                    isLast: app == pins.last,
                    onLaunch: { pinnedStore.launch(app) },
                    onUnpin: { pinnedStore.unpin(bundleID: app.bundleID) },
                    onMove: { pinnedStore.move(app, by: $0) }
                )
                .onDrag {
                    NSItemProvider(object: app.bundleID as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: PinnedDropDelegate(targetID: app.bundleID) { sourceID in
                        pinnedStore.move(sourceID: sourceID, onto: app.bundleID)
                    }
                )
            }
        }
    }
}

/// Accepts a dragged pinned chip and reports the dragged app's bundle ID.
private struct PinnedDropDelegate: DropDelegate {
    let targetID: String
    let onDrop: @MainActor (String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { [targetID, onDrop] item, _ in
            guard let sourceID = item as? String, sourceID != targetID else { return }
            Task { @MainActor in onDrop(sourceID) }
        }
        return true
    }
}

private struct PinnedChip: View {
    let app: PinnedApp
    let size: BarSize
    let isRunning: Bool
    let isFrontmost: Bool
    let badge: String?
    let isFirst: Bool
    let isLast: Bool
    let onLaunch: () -> Void
    let onUnpin: () -> Void
    /// Moves the chip by the given offset: -1 is left, +1 is right.
    let onMove: (Int) -> Void
    @State private var hover = false

    private var accessibilityState: String? {
        if isFrontmost { return "frontmost" }
        return isRunning ? "running" : nil
    }

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 2) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: size.chipHeight - 6, height: size.chipHeight - 6)
                    .overlay(alignment: .topTrailing) {
                        if let badge { NotificationBadge(text: badge).offset(x: 4, y: -4) }
                    }
                Circle()
                    .fill(isRunning ? ChipStyle.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .fill(hover ? ChipStyle.hoverFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(app.name)
        .accessibilityLabel(ChipAccessibility.label(app.name, state: accessibilityState, badge: badge))
        .contextMenu {
            Button("Activate \(app.name)") { onLaunch() }
            if !isFirst || !isLast {
                Divider()
                if !isFirst { Button("Move Left") { onMove(-1) } }
                if !isLast { Button("Move Right") { onMove(1) } }
            }
            Divider()
            Button("Unpin from Bar") { onUnpin() }
        }
    }
}
