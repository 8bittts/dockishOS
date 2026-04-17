import SwiftUI
import AppKit

/// Scrollable horizontal list of window chips for the current Space.
/// Branches between flat-window and grouped-by-app rendering based on the
/// `groupWindowsByApp` setting.
struct WindowsRow: View {
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var badgeStore: BadgeStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if settings.groupWindowsByApp {
                    let groups = windowStore.grouped()
                    ForEach(groups) { group in groupChip(for: group) }
                    if groups.isEmpty { emptyState }
                } else {
                    ForEach(windowStore.windows, id: \.id) { window in
                        chip(for: window)
                    }
                    if windowStore.windows.isEmpty { emptyState }
                }
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Text("No windows on this Space")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func chip(for window: WindowInfo) -> some View {
        let isPinned = pinnedStore.isPinned(bundleID: window.bundleID)
        let badge = badgeStore.badge(for: window.bundleID)
        WindowChip(
            window: window,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: window.pid == windowStore.frontmostPID,
            isPinned: isPinned,
            badge: badge,
            onActivate: { windowStore.activate(window) },
            onClose: { windowStore.close(window) },
            onTogglePin: {
                if let bid = window.bundleID, pinnedStore.isPinned(bundleID: bid) {
                    pinnedStore.unpin(bundleID: bid)
                } else {
                    pinnedStore.pin(window: window)
                }
            }
        )
    }

    @ViewBuilder
    private func groupChip(for group: WindowGroup) -> some View {
        let isPinned = pinnedStore.isPinned(bundleID: group.bundleID)
        let isFrontmost = group.windows.contains(where: { $0.pid == windowStore.frontmostPID })
        let badge = badgeStore.badge(for: group.bundleID)
        WindowGroupChip(
            group: group,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: isFrontmost,
            isPinned: isPinned,
            badge: badge,
            previewWindow: windowStore.nextWindow(in: group),
            onActivateNext: { windowStore.activateNext(in: group) },
            onActivate: { windowStore.activate($0) },
            onClose: { windowStore.close($0) },
            onTogglePin: {
                if let bid = group.bundleID, pinnedStore.isPinned(bundleID: bid) {
                    pinnedStore.unpin(bundleID: bid)
                } else if let win = group.windows.first {
                    pinnedStore.pin(window: win)
                }
            }
        )
    }
}

private struct WindowChip: View {
    let window: WindowInfo
    let size: BarSize
    let showTitle: Bool
    let isFrontmost: Bool
    let isPinned: Bool
    let badge: String?
    let onActivate: () -> Void
    let onClose: () -> Void
    let onTogglePin: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 6) {
                AppIconView(pid: window.pid)
                    .frame(width: size.chipIconSize, height: size.chipIconSize)
                    .overlay(alignment: .topTrailing) {
                        if let badge { NotificationBadge(text: badge).offset(x: 4, y: -4) }
                    }
                if showTitle {
                    Text(window.displayTitle)
                        .font(.system(size: size.chipHeight * 0.40, weight: isFrontmost ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: size.chipHeight)
            .frame(maxWidth: showTitle ? 220 : nil)
            .background(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .fill(chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .stroke(isFrontmost ? Color.accentColor.opacity(ChipStyle.strokeOpacity) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hover = hovering
            if hovering {
                ThumbnailController.shared.requestShow(window, near: NSEvent.mouseLocation)
            } else {
                ThumbnailController.shared.cancelShow()
            }
        }
        .help(window.displayTitle)
        .accessibilityLabel("\(window.displayTitle)\(isFrontmost ? ", frontmost" : "")\(badge.map { ", \($0) notifications" } ?? "")")
        .contextMenu {
            Button("Activate") { onActivate() }
            Button("Close Window") { onClose() }
            Divider()
            Button(isPinned ? "Unpin App from Bar" : "Pin App to Bar") { onTogglePin() }
        }
    }

    private var chipFill: Color {
        if isFrontmost { return Color.white.opacity(ChipStyle.frontmostOpacity) }
        return Color.white.opacity(hover ? ChipStyle.hoverOpacity : ChipStyle.inactiveOpacity)
    }
}

private struct WindowGroupChip: View {
    let group: WindowGroup
    let size: BarSize
    let showTitle: Bool
    let isFrontmost: Bool
    let isPinned: Bool
    let badge: String?
    let previewWindow: WindowInfo?
    let onActivateNext: () -> Void
    let onActivate: (WindowInfo) -> Void
    let onClose: (WindowInfo) -> Void
    let onTogglePin: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onActivateNext) {
            HStack(spacing: 6) {
                AppIconView(pid: group.pid)
                    .frame(width: size.chipIconSize, height: size.chipIconSize)
                    .overlay(alignment: .topTrailing) {
                        // Notification badge wins over window count when both apply.
                        if let badge {
                            NotificationBadge(text: badge).offset(x: 6, y: -4)
                        } else if group.windows.count > 1 {
                            Text("\(group.windows.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor))
                                .offset(x: 6, y: -4)
                        }
                    }
                if showTitle {
                    Text(group.ownerName)
                        .font(.system(size: size.chipHeight * 0.40, weight: isFrontmost ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: size.chipHeight)
            .frame(maxWidth: showTitle ? 220 : nil)
            .background(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .fill(chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .stroke(isFrontmost ? Color.accentColor.opacity(ChipStyle.strokeOpacity) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hover = hovering
            if hovering, let preview = previewWindow {
                ThumbnailController.shared.requestShow(preview, near: NSEvent.mouseLocation)
            } else {
                ThumbnailController.shared.cancelShow()
            }
        }
        .help("\(group.ownerName) — \(group.windows.count) window\(group.windows.count == 1 ? "" : "s")")
        .accessibilityLabel("\(group.ownerName), \(group.windows.count) windows\(badge.map { ", \($0) notifications" } ?? "")")
        .contextMenu {
            ForEach(group.windows, id: \.id) { window in
                Button(window.displayTitle.isEmpty ? "(untitled)" : window.displayTitle) {
                    onActivate(window)
                }
            }
            Divider()
            Button("Close All Windows") {
                for w in group.windows { onClose(w) }
            }
            Divider()
            Button(isPinned ? "Unpin App from Bar" : "Pin App to Bar") { onTogglePin() }
        }
    }

    private var chipFill: Color {
        if isFrontmost { return Color.white.opacity(ChipStyle.frontmostOpacity) }
        return Color.white.opacity(hover ? ChipStyle.hoverOpacity : ChipStyle.inactiveOpacity)
    }
}
