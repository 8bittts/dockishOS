import AppKit
import SwiftUI

final class BarController {
    private let screen: NSScreen
    private let panel: BarPanel
    private let host: NSHostingView<BarView>
    private var scrollMonitor: Any?
    private var lastSpaceSwitchAt: TimeInterval = 0
    private let scrollCooldown: TimeInterval = 0.25

    init(screen: NSScreen) {
        self.screen = screen
        let settings = SettingsStore.shared
        let height = settings.barSize.height
        let visible = screen.visibleFrame
        let y: CGFloat = settings.barPosition == .top
            ? visible.maxY - height
            : visible.minY
        let frame = NSRect(
            x: visible.minX,
            y: y,
            width: visible.width,
            height: height
        )
        self.panel = BarPanel(contentRect: frame)
        self.host = NSHostingView(rootView: BarView(
            screen: screen,
            windowStore: WindowStore.shared,
            spacesStore: SpacesStore.shared,
            pinnedStore: PinnedAppsStore.shared,
            badgeStore: BadgeStore.shared,
            settings: SettingsStore.shared
        ))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(frame, display: true)
    }

    func show() {
        panel.orderFrontRegardless()
        installScrollMonitor()
    }

    func close() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        panel.orderOut(nil)
        panel.close()
    }

    /// Vertical scroll over the bar switches Spaces. Horizontal scroll is
    /// passed through so the windows row's `ScrollView` still scrolls.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                self.handleVerticalScroll(deltaY: event.scrollingDeltaY)
                return nil
            }
            return event
        }
    }

    private func handleVerticalScroll(deltaY: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSpaceSwitchAt > scrollCooldown else { return }
        let direction = deltaY > 0 ? -1 : 1
        let store = SpacesStore.shared
        let spaces = store.spaces(for: screen)
        guard
            !spaces.isEmpty,
            let currentID = store.currentSpaceID(for: screen),
            let idx = spaces.firstIndex(where: { $0.id == currentID })
        else { return }
        let next = idx + direction
        guard spaces.indices.contains(next) else { return }
        store.switchTo(spaces[next])
        lastSpaceSwitchAt = now
    }
}
