import SwiftUI
import AppKit

/// Persistent row of pinned apps. Click to launch / activate, drag to
/// reorder, right-click for unpin / move.
struct PinnedRow: View {
    let size: BarSize
    let pins: [PinnedApp]
    @ObservedObject var runningApps: RunningAppsStore
    @ObservedObject var badgeStore: BadgeStore
    let onLaunch: (PinnedApp) -> Void
    let onUnpin: (PinnedApp) -> Void
    let onMove: (PinnedApp, Int) -> Void
    let onReorder: (String, String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(pins) { app in
                PinnedChip(
                    app: app,
                    size: size,
                    isRunning: runningApps.contains(app.bundleID),
                    isFrontmost: runningApps.isFrontmost(app.bundleID),
                    badge: badgeStore.badge(for: app.bundleID),
                    action: { onLaunch(app) },
                    onUnpin: { onUnpin(app) },
                    onMoveLeft: { onMove(app, -1) },
                    onMoveRight: { onMove(app, 1) }
                )
                .onDrag {
                    NSItemProvider(object: app.bundleID as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: PinnedDropDelegate(targetID: app.bundleID, onReorder: onReorder)
                )
            }
        }
    }
}

private struct PinnedDropDelegate: DropDelegate {
    let targetID: String
    let onReorder: (String, String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let sourceID = item as? String, sourceID != targetID else { return }
            DispatchQueue.main.async { onReorder(sourceID, targetID) }
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
    let action: () -> Void
    let onUnpin: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: size.pinnedChipSize - 6, height: size.pinnedChipSize - 6)
                    .overlay(alignment: .topTrailing) {
                        if let badge { NotificationBadge(text: badge).offset(x: 4, y: -4) }
                    }
                Circle()
                    .fill(isRunning ? Color.white.opacity(0.85) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .fill(Color.white.opacity(hover ? ChipStyle.hoverOpacity : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(app.name)
        .accessibilityLabel("\(app.name)\(isFrontmost ? ", frontmost" : isRunning ? ", running" : "")\(badge.map { ", \($0) notifications" } ?? "")")
        .contextMenu {
            Button("Activate \(app.name)") { action() }
            Divider()
            Button("Move Left")  { onMoveLeft()  }
            Button("Move Right") { onMoveRight() }
            Divider()
            Button("Unpin") { onUnpin() }
        }
    }
}
