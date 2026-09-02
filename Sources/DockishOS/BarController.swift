import AppKit
import DockishOSCore
import QuartzCore
import SwiftUI

final class BarController {
    private let screen: NSScreen
    private let panel: BarPanel
    private let host: NSHostingView<BarView>
    private let presentation: BarPresentationState
    private var scrollMonitor: Any?
    private var collapseObserver: NSObjectProtocol?
    private var lastSpaceSwitchAt: TimeInterval = 0
    private var isAnimatingCollapse = false
    private var queuedCollapseTarget: Bool?
    private let scrollCooldown: TimeInterval = 0.25

    init(screen: NSScreen) {
        self.screen = screen
        self.presentation = BarPresentationState(isCollapsed: SettingsStore.shared.barCollapsed)
        let frame = BarGeometry.visibleFrame(Self.geometryInput(screen: screen, collapsed: presentation.isCollapsed))
        self.panel = BarPanel(contentRect: frame)
        self.host = NSHostingView(rootView: BarView(
            windowStore: WindowStore.shared,
            pinnedStore: PinnedAppsStore.shared,
            badgeStore: BadgeStore.shared,
            runningApps: RunningAppsStore.shared,
            settings: SettingsStore.shared,
            presentation: presentation
        ))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(frame, display: true)

        collapseObserver = NotificationCenter.default.addObserver(
            forName: .dockishBarCollapseDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCollapsePreferenceChange()
        }
    }

    func show() {
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        installScrollMonitor()
    }

    func close() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let observer = collapseObserver {
            NotificationCenter.default.removeObserver(observer)
            collapseObserver = nil
        }
        panel.ignoresMouseEvents = false
        panel.orderOut(nil)
        panel.close()
    }

    /// Vertical scroll over the bar switches Spaces. Horizontal scroll is
    /// passed through so the windows row's `ScrollView` still scrolls.
    private func installScrollMonitor() {
        // Idempotent: avoid stacking multiple monitors if `show()` is
        // called twice without a matching `close()`.
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                if self.presentation.isCollapsed || self.isAnimatingCollapse {
                    return nil
                }
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

    private func handleCollapsePreferenceChange() {
        let targetCollapsed = SettingsStore.shared.barCollapsed
        guard targetCollapsed != presentation.isCollapsed || isAnimatingCollapse else { return }
        if isAnimatingCollapse {
            queuedCollapseTarget = targetCollapsed
            return
        }
        animate(toCollapsed: targetCollapsed)
    }

    /// Two-phase slide: hide the panel in its current (starting) presentation,
    /// swap to the target presentation off-screen, then slide it back into view.
    /// Collapse and expand are structural mirrors — the only differences are the
    /// start/target `isCollapsed` states and the per-phase animation durations.
    private func animate(toCollapsed: Bool) {
        isAnimatingCollapse = true
        queuedCollapseTarget = nil
        panel.ignoresMouseEvents = true
        let startCollapsed = !toCollapsed
        let initialVisible = visibleFrame(collapsed: startCollapsed)
        let initialHidden = hiddenFrame(collapsed: startCollapsed)
        let finalHidden = hiddenFrame(collapsed: toCollapsed)
        let finalVisible = visibleFrame(collapsed: toCollapsed)
        // Collapse uses 0.16/0.16; expand uses 0.14/0.18.
        let hideDuration: TimeInterval = toCollapsed ? 0.16 : 0.14
        let revealDuration: TimeInterval = toCollapsed ? 0.16 : 0.18

        presentation.isCollapsed = startCollapsed
        panel.setFrame(initialVisible, display: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(initialHidden, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.presentation.isCollapsed = toCollapsed
            self.panel.setFrame(finalHidden, display: true)
            self.host.layoutSubtreeIfNeeded()
            self.panel.layoutIfNeeded()
            self.panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = revealDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(finalVisible, display: true)
            } completionHandler: { [weak self] in
                self?.finishCollapseAnimation()
            }
        }
    }

    private func visibleFrame(collapsed: Bool) -> NSRect {
        BarGeometry.visibleFrame(geometryInput(collapsed: collapsed))
    }

    private func hiddenFrame(collapsed: Bool) -> NSRect {
        BarGeometry.hiddenFrame(geometryInput(collapsed: collapsed))
    }

    private func geometryInput(collapsed: Bool) -> BarGeometryInput {
        Self.geometryInput(screen: screen, collapsed: collapsed)
    }

    private static func geometryInput(screen: NSScreen, collapsed: Bool) -> BarGeometryInput {
        let settings = SettingsStore.shared
        return BarGeometryInput(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            collapsed: collapsed,
            barOnTop: settings.barPosition == .top,
            tabOnRight: settings.collapsedTabPosition.isRightEdge,
            barHeight: settings.barSize.height
        )
    }

    private func finishCollapseAnimation() {
        isAnimatingCollapse = false
        let currentTarget = SettingsStore.shared.barCollapsed
        if let queuedCollapseTarget, queuedCollapseTarget != presentation.isCollapsed {
            self.queuedCollapseTarget = nil
            animate(toCollapsed: queuedCollapseTarget)
            return
        }
        if currentTarget != presentation.isCollapsed {
            handleCollapsePreferenceChange()
            return
        }
        panel.ignoresMouseEvents = false
    }
}
