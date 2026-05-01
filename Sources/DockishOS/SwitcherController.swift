import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Modal-ish app/window switcher panel triggered by a global hotkey
/// (default: ⌥ Tab). Lists windows on the current Space; Tab/arrows
/// cycle, Return activates, Esc dismisses, click-outside dismisses.
final class SwitcherController {
    static let shared = SwitcherController()

    private let panel: SwitcherPanel
    private var hostingView: NSHostingView<SwitcherView>?
    private var resignObserver: NSObjectProtocol?
    private var previousActiveApp: NSRunningApplication?
    private var selectedIndex: Int = 0

    private init() {
        let size = NSSize(width: 720, height: 200)
        panel = SwitcherPanel(size: size)
        panel.onAdvance = { [weak self] delta in
            self?.advanceSelection(by: delta)
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        WindowStore.shared.refresh()
        let count = WindowStore.shared.windows.count
        // Default to "next" window so a quick ⌥Tab tap mirrors the macOS
        // built-in switcher behavior of jumping to the previous app.
        selectedIndex = count > 1 ? 1 : 0
        rebuildView()
        positionOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        if let previousActiveApp {
            AppActivation.activate(previousActiveApp)
        }
        previousActiveApp = nil
    }

    private func activate(_ window: WindowInfo) {
        // Don't restore previousActiveApp — the switcher's whole job is to
        // change the frontmost window.
        previousActiveApp = nil
        panel.orderOut(nil)
        WindowStore.shared.activate(window)
    }

    private func advanceSelection(by delta: Int) {
        let count = WindowStore.shared.windows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
        rebuildView()
    }

    private func rebuildView() {
        let view = SwitcherView(
            store: WindowStore.shared,
            selectedIndex: Binding(
                get: { self.selectedIndex },
                set: { self.selectedIndex = $0 }
            ),
            onActivate: { [weak self] in self?.activate($0) },
            onDismiss: { [weak self] in self?.hide() }
        )
        if let hostingView {
            hostingView.rootView = view
            return
        }
        let host = NSHostingView(rootView: view)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        hostingView = host
    }

    private func positionOnActiveScreen() {
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}

final class SwitcherPanel: NSPanel {
    var onAdvance: ((Int) -> Void)?

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleTab(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleTab(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleTab(_ event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(kVK_Tab) else { return false }
        onAdvance?(event.modifierFlags.contains(.shift) ? -1 : 1)
        return true
    }
}
