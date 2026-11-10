import AppKit
import DockishOSCore
import QuartzCore
import SwiftUI

@MainActor
final class BarController {
    private static let scrollCooldown: TimeInterval = 0.25

    private let screen: NSScreen
    private let panel: BarPanel
    private let host: NSHostingView<BarView>
    private let presentation: BarPresentationState
    private var scrollMonitor: Any?
    private var collapseObserver: NSObjectProtocol?
    private var lastSpaceSwitchAt: TimeInterval = 0
    private var isAnimatingCollapse = false

    init(screen: NSScreen) {
        self.screen = screen
        presentation = BarPresentationState(isCollapsed: SettingsStore.shared.barCollapsed)
        let frame = BarGeometry.visibleFrame(
            Self.geometryInput(screen: screen, collapsed: presentation.isCollapsed)
        )
        panel = BarPanel(contentRect: frame)
        host = NSHostingView(rootView: BarView(
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

        collapseObserver = NotificationCenter.default.observeOnMain(
            .dockishBarCollapseDidChange
        ) { [weak self] _ in
            self?.handleCollapsePreferenceChange()
        }
    }

    func show() {
        panel.orderFrontRegardless()
        installScrollMonitor()
    }

    func close() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        if let collapseObserver {
            NotificationCenter.default.removeObserver(collapseObserver)
            self.collapseObserver = nil
        }
        panel.close()
    }

    /// Vertical scroll over the bar switches Spaces. Horizontal scroll is
    /// passed through so the windows row's `ScrollView` still scrolls.
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return event }
            if !self.presentation.isCollapsed, !self.isAnimatingCollapse {
                self.handleVerticalScroll(deltaY: event.scrollingDeltaY)
            }
            return nil
        }
    }

    private func handleVerticalScroll(deltaY: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSpaceSwitchAt > Self.scrollCooldown else { return }
        guard let next = SpacesAPI.adjacentSpace(for: screen, direction: deltaY > 0 ? -1 : 1) else { return }
        SpacesAPI.switchTo(next)
        lastSpaceSwitchAt = now
    }

    /// Starts the slide toward the collapsed preference. A change that arrives
    /// mid-animation waits: `finishCollapseAnimation` reads the preference again.
    private func handleCollapsePreferenceChange() {
        let targetCollapsed = SettingsStore.shared.barCollapsed
        guard !isAnimatingCollapse, targetCollapsed != presentation.isCollapsed else { return }
        animate(toCollapsed: targetCollapsed)
    }

    /// Two-phase slide: hide the panel in its current (starting) presentation,
    /// swap to the target presentation off-screen, then slide it back into view.
    /// Collapse and expand are structural mirrors — the only differences are the
    /// start/target `isCollapsed` states and the per-phase animation durations.
    private func animate(toCollapsed: Bool) {
        isAnimatingCollapse = true
        panel.ignoresMouseEvents = true
        let startCollapsed = !toCollapsed
        let initialVisible = visibleFrame(collapsed: startCollapsed)
        let initialHidden = hiddenFrame(collapsed: startCollapsed)
        let finalHidden = hiddenFrame(collapsed: toCollapsed)
        let finalVisible = visibleFrame(collapsed: toCollapsed)
        // Collapse uses 0.16/0.16; expand uses 0.14/0.18.
        let hideDuration: TimeInterval = toCollapsed ? 0.16 : 0.14
        let revealDuration: TimeInterval = toCollapsed ? 0.16 : 0.18

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            presentation.isCollapsed = toCollapsed
            panel.setFrame(finalVisible, display: true)
            finishCollapseAnimation()
            return
        }

        presentation.isCollapsed = startCollapsed
        panel.setFrame(initialVisible, display: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(initialHidden, display: true)
        } completionHandler: { [weak self] in
            // AppKit runs animation completion handlers on the main thread.
            MainActor.assumeIsolated {
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
                    MainActor.assumeIsolated {
                        self?.finishCollapseAnimation()
                    }
                }
            }
        }
    }

    private func finishCollapseAnimation() {
        isAnimatingCollapse = false
        let targetCollapsed = SettingsStore.shared.barCollapsed
        if targetCollapsed != presentation.isCollapsed {
            animate(toCollapsed: targetCollapsed)
        } else {
            panel.ignoresMouseEvents = false
        }
    }

    private func visibleFrame(collapsed: Bool) -> NSRect {
        BarGeometry.visibleFrame(Self.geometryInput(screen: screen, collapsed: collapsed))
    }

    private func hiddenFrame(collapsed: Bool) -> NSRect {
        BarGeometry.hiddenFrame(Self.geometryInput(screen: screen, collapsed: collapsed))
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
}
