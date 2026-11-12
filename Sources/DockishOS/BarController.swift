import AppKit
import DockishOSCore
import QuartzCore
import SwiftUI

@MainActor
final class BarController {
    private static let scrollCooldown: TimeInterval = 0.25

    /// The settings that decide what the panel shows and where it sits.
    private struct Layout: Equatable {
        var collapsed: Bool
        var barOnTop: Bool
        var tabOnRight: Bool
        var size: BarSize

        @MainActor
        static var current: Layout {
            let settings = SettingsStore.shared
            return Layout(
                collapsed: settings.barCollapsed,
                barOnTop: settings.barPosition == .top,
                tabOnRight: settings.collapsedTabPosition.isRightEdge,
                size: settings.barSize
            )
        }
    }

    /// The two halves of a transition.
    private enum Phase {
        case out, `in`
    }

    let displayUUID: String
    private let screen: NSScreen
    private let panel: BarPanel
    private let host: NSHostingView<BarView>
    private let presentation: BarPresentationState
    /// The layout on screen. It trails `Layout.current` while a transition runs.
    private var presented: Layout
    private var scrollMonitor: Any?
    private var collapseObserver: NSObjectProtocol?
    private var lastSpaceSwitchAt: TimeInterval = 0
    private var isTransitioning = false

    init(screen: NSScreen) {
        self.screen = screen
        displayUUID = screen.displayUUID
        presented = .current
        presentation = BarPresentationState(isCollapsed: presented.collapsed, barSize: presented.size)
        let frame = BarGeometry.visibleFrame(Self.geometryInput(screen: screen, layout: presented))
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
            self?.followSettings()
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

    /// Brings the panel to the current settings. A change that moves nothing
    /// on screen applies at once; any other runs one transition: the old
    /// surface leaves, the panel swaps while out of sight, the new one enters.
    /// A change during a transition waits, and `finishTransition` reads again.
    func followSettings() {
        let target = Layout.current
        guard !isTransitioning, target != presented else { return }

        if !changesWhatIsOnScreen(from: presented, to: target) {
            presented = target
            return
        }
        transition(from: presented, to: target)
    }

    /// True unless the surface keeps its kind, size and frame, as when the
    /// corner changes while the bar is expanded.
    private func changesWhatIsOnScreen(from old: Layout, to new: Layout) -> Bool {
        old.collapsed != new.collapsed
            || old.size != new.size
            || visibleFrame(old) != visibleFrame(new)
    }

    private func transition(from old: Layout, to new: Layout) {
        isTransitioning = true
        panel.ignoresMouseEvents = true
        run(.out, layout: old) { [weak self] in
            guard let self else { return }
            self.presented = new
            self.presentation.isCollapsed = new.collapsed
            self.presentation.barSize = new.size
            self.host.layoutSubtreeIfNeeded()
            self.run(.in, layout: new) { [weak self] in
                self?.finishTransition()
            }
        }
    }

    /// One phase. A slide moves the panel through the bottom edge; a fade
    /// changes only its opacity, in place.
    private func run(_ phase: Phase, layout: Layout, completion: @escaping @MainActor () -> Void) {
        let input = Self.geometryInput(screen: screen, layout: layout)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let style = BarGeometry.transition(input, reduceMotion: reduceMotion)
        let visible = BarGeometry.visibleFrame(input)

        if phase == .in {
            panel.setFrame(style == .slide ? BarGeometry.hiddenFrame(input) : visible, display: true)
            panel.alphaValue = style == .fade ? 0 : 1
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.phase
            context.timingFunction = CAMediaTimingFunction(name: phase == .out ? .easeIn : .easeOut)
            switch (style, phase) {
            case (.slide, .out): panel.animator().setFrame(BarGeometry.hiddenFrame(input), display: true)
            case (.slide, .in):  panel.animator().setFrame(visible, display: true)
            case (.fade, .out):  panel.animator().alphaValue = 0
            case (.fade, .in):   panel.animator().alphaValue = 1
            }
        } completionHandler: {
            // AppKit runs animation completion handlers on the main thread.
            MainActor.assumeIsolated(completion)
        }
    }

    private func finishTransition() {
        isTransitioning = false
        if Layout.current != presented {
            followSettings()
        } else {
            panel.ignoresMouseEvents = false
        }
    }

    /// Vertical scroll over the bar switches Spaces. Horizontal scroll is
    /// passed through so the windows row's `ScrollView` still scrolls.
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return event }
            if !self.presentation.isCollapsed, !self.isTransitioning {
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

    private func visibleFrame(_ layout: Layout) -> NSRect {
        BarGeometry.visibleFrame(Self.geometryInput(screen: screen, layout: layout))
    }

    private static func geometryInput(screen: NSScreen, layout: Layout) -> BarGeometryInput {
        BarGeometryInput(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            collapsed: layout.collapsed,
            barOnTop: layout.barOnTop,
            tabOnRight: layout.tabOnRight,
            barHeight: layout.size.height
        )
    }
}
