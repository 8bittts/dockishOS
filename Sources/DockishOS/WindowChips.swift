import SwiftUI
import AppKit
import DockishOSCore

/// Scrollable horizontal list of window chips for the current Space.
/// Branches between flat-window and grouped-by-app rendering based on the
/// `groupWindowsByApp` setting.
struct WindowsRow: View {
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var badgeStore: BadgeStore
    @ObservedObject var settings: SettingsStore
    private let reorderAnimation = Animation.spring(response: 0.30, dampingFraction: 0.82)

    /// An app with a chip in the pinned row gets no second chip here.
    private var hidesPinnedApps: Bool {
        settings.showPinnedRow && !pinnedStore.pins.isEmpty
    }

    private var visibleWindows: [WindowInfo] {
        guard hidesPinnedApps else { return windowStore.windows }
        return windowStore.windows.filter { !pinnedStore.isPinned(bundleID: $0.bundleID) }
    }

    private func isFrontmost(_ group: AppWindowGroup) -> Bool {
        group.windows.contains { $0.pid == windowStore.frontmostPID }
    }

    var body: some View {
        // Derive the lists once per body pass: the chips and the animation
        // value both read them.
        let visibleWindows = visibleWindows
        let windows = settings.groupWindowsByApp ? [] : visibleWindows
        let groups = settings.groupWindowsByApp ? WindowGrouping.group(visibleWindows) : []

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups) { groupChip(for: $0) }
                ForEach(windows) { chip(for: $0) }
                if visibleWindows.isEmpty {
                    Text("No open apps in this space…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 10)
            // A reorder, a retitle and a focus change all move chips.
            .animation(reorderAnimation, value: visibleWindows)
            .animation(reorderAnimation, value: windowStore.frontmostPID)
        }
    }

    private func chip(for window: WindowInfo) -> some View {
        let isFrontmost = window.pid == windowStore.frontmostPID
        let badge = badgeStore.badge(for: window.bundleID)
        return Chip(
            pid: window.pid,
            title: window.displayTitle,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: isFrontmost,
            badge: badge,
            windowCount: 1,
            help: window.displayTitle,
            accessibilityLabel: ChipAccessibility.label(
                window.displayTitle,
                state: isFrontmost ? "frontmost" : nil,
                badge: badge
            ),
            action: { windowStore.activate(window) }
        ) {
            Button("Activate") { windowStore.activate(window) }
            Button("Close Window", role: .destructive) { windowStore.close(window) }
            Divider()
            pinToggle(for: window)
        }
    }

    private func groupChip(for group: AppWindowGroup) -> some View {
        let isFrontmost = isFrontmost(group)
        let badge = badgeStore.badge(for: group.bundleID)
        let countText = ChipAccessibility.windowCountText(group.windows.count)
        return Chip(
            pid: group.pid,
            title: group.ownerName,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: isFrontmost,
            badge: badge,
            windowCount: group.windows.count,
            help: "\(group.ownerName) — \(countText)",
            accessibilityLabel: ChipAccessibility.label(
                group.ownerName,
                windowCount: group.windows.count,
                state: isFrontmost ? "frontmost" : nil,
                badge: badge
            ),
            action: { windowStore.activateNext(in: group) }
        ) {
            ForEach(group.windows) { window in
                Button(window.title.isEmpty ? "Untitled" : window.title) {
                    windowStore.activate(window)
                }
            }
            Divider()
            Button("Close All Windows", role: .destructive) {
                group.windows.forEach(windowStore.close)
            }
            Divider()
            if let window = group.windows.first {
                pinToggle(for: window)
            }
        }
    }

    /// Pins or unpins the app that owns `window`.
    @ViewBuilder
    private func pinToggle(for window: WindowInfo) -> some View {
        if let bundleID = window.bundleID, pinnedStore.isPinned(bundleID: bundleID) {
            Button("Unpin from Bar") { pinnedStore.unpin(bundleID: bundleID) }
        } else {
            Button("Pin to Bar") { pinnedStore.pin(window: window) }
        }
    }
}

/// One chip in the windows row: a single window, or every window of an app
/// when grouping is on.
private struct Chip<MenuItems: View>: View {
    let pid: pid_t
    let title: String
    let size: BarSize
    let showTitle: Bool
    let isFrontmost: Bool
    let badge: String?
    let windowCount: Int
    let help: String
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let menuItems: () -> MenuItems
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AppIconView(pid: pid)
                    .frame(width: size.chipIconSize, height: size.chipIconSize)
                    .overlay(alignment: .topTrailing) {
                        if let badge {
                            NotificationBadge(text: badge).offset(x: 6, y: -4)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if windowCount > 1 {
                            WindowCountMark(count: windowCount).offset(x: 6, y: 4)
                        }
                    }
                if showTitle {
                    Text(title)
                        .font(.system(size: size.chipHeight * 0.40, weight: isFrontmost ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, ChipStyle.labelHorizontalPadding)
                        .padding(.vertical, ChipStyle.labelVerticalPadding)
                        .background(ChipChrome(isFrontmost: isFrontmost, hover: hover))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: size.chipHeight)
            .frame(maxWidth: showTitle ? 220 : nil)
            .background {
                // With titles on, the hover and frontmost fill sits behind the
                // label only. With titles off there is no label to carry it,
                // so the whole chip keeps the chrome.
                if !showTitle {
                    ChipChrome(isFrontmost: isFrontmost, hover: hover)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(ChipStyle.hoverAnimation, value: hover)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu(menuItems: menuItems)
    }
}

/// Chip background (fill + border + top highlight). Only hover and frontmost
/// draw chrome: an idle chip stays plain so the bar reads as icons and labels
/// rather than a row of pills.
private struct ChipChrome: View {
    let isFrontmost: Bool
    let hover: Bool

    private var fill: Color {
        if isFrontmost { return ChipStyle.frontmostFill }
        return hover ? ChipStyle.hoverFill : .clear
    }

    private var borderOpacity: Double {
        if hover { return ChipStyle.hoverBorderOpacity }
        return isFrontmost ? ChipStyle.frontmostBorderOpacity : 0
    }

    private var topHighlightOpacity: Double {
        if hover { return ChipStyle.hoverTopHighlightOpacity }
        return isFrontmost ? ChipStyle.topHighlightOpacity : 0
    }

    var body: some View {
        RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .strokeBorder(ChipStyle.border.opacity(borderOpacity), lineWidth: 0.65)
            }
            .overlay {
                // Gradient stops rather than a fixed height, so the highlight
                // scales with the label pill instead of the chip.
                RoundedRectangle(cornerRadius: ChipStyle.cornerRadius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(nsColor: .highlightColor).opacity(topHighlightOpacity), location: 0),
                                .init(color: Color(nsColor: .highlightColor).opacity(0), location: 0.45),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
    }
}
