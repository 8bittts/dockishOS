import AppKit
import Carbon.HIToolbox
import Combine
import DockishOSCore
import SwiftUI

/// Which window the switcher has selected, as an index into the window list.
@MainActor
final class SwitcherSelection: ObservableObject {
    @Published var index = 0

    /// Moves the selection by `delta`, wrapping at both ends of `count` windows.
    func advance(by delta: Int, count: Int) {
        index = SelectionWrap.advance(index, by: delta, count: count)
    }
}

/// App/window switcher panel triggered by a global hotkey (default: ⌥ Tab).
/// Lists windows on the current Space; Tab and the arrow keys cycle, Return
/// activates, Esc dismisses, click-outside dismisses.
@MainActor
final class SwitcherController {
    static let shared = SwitcherController()

    private let panel = SwitcherPanel()
    private let selection = SwitcherSelection()
    private let windowStore = WindowStore.shared

    private init() {
        panel.onCommand = { [weak self] in self?.perform($0) }
        panel.setContent(SwitcherView(
            store: windowStore,
            selection: selection,
            onActivate: { [weak self] in self?.activate($0) }
        ))
    }

    func toggle() {
        guard !panel.isVisible else { return panel.dismiss() }
        windowStore.refresh()
        // Default to "next" window so a quick ⌥Tab tap mirrors the macOS
        // built-in switcher behavior of jumping to the previous app.
        selection.index = windowStore.windows.count > 1 ? 1 : 0
        panel.present()
    }

    private func perform(_ command: SwitcherPanel.Command) {
        let windows = windowStore.windows
        switch command {
        case .advance(let delta):
            selection.advance(by: delta, count: windows.count)
        case .activateSelection:
            if windows.indices.contains(selection.index) {
                activate(windows[selection.index])
            }
        case .dismiss:
            panel.dismiss()
        }
    }

    private func activate(_ window: WindowInfo) {
        panel.dismiss()
        windowStore.activate(window)
    }
}

/// The switcher's panel: borderless, floating, and key without activating the
/// app, so the app the user was in stays active behind it.
///
/// It reads the switcher's keys itself: the SwiftUI content holds no keyboard
/// focus, and AppKit would spend Tab on key-view navigation.
final class SwitcherPanel: NSPanel {
    enum Command {
        /// Move the selection by this many windows; negative moves back.
        case advance(Int)
        case activateSelection
        case dismiss
    }

    var onCommand: ((Command) -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        // Liquid Glass casts its own shadow, and a window shadow on top of it
        // outlines the panel's rectangle.
        if #available(macOS 26, *) {
            hasShadow = false
        } else {
            hasShadow = true
        }
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Borderless, so VoiceOver has no visible title to read.
    override func accessibilityTitle() -> String? { "App switcher" }

    /// Installs SwiftUI content that fills the panel. The panel keeps the
    /// size it was created with: left to its default sizing options, the
    /// hosting view resizes the window to the content's smallest size.
    func setContent(_ view: some View) {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        contentView = host
    }

    /// Shows the panel in the middle of the screen under the pointer and
    /// gives it key focus.
    func present() {
        if let visibleFrame = NSScreen.containing(NSEvent.mouseLocation)?.visibleFrame {
            setFrameOrigin(NSPoint(
                x: visibleFrame.midX - frame.width / 2,
                y: visibleFrame.midY - frame.height / 2
            ))
        }
        makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        orderOut(nil)
    }

    /// Click-outside and focus loss close the panel.
    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event) || super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if !handle(event) {
            super.keyDown(with: event)
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let command = command(for: event) else { return false }
        onCommand?(command)
        return true
    }

    private func command(for event: NSEvent) -> Command? {
        switch Int(event.keyCode) {
        case kVK_Tab:                           return .advance(event.modifierFlags.contains(.shift) ? -1 : 1)
        case kVK_RightArrow:                    return .advance(1)
        case kVK_LeftArrow:                     return .advance(-1)
        case kVK_Return, kVK_ANSI_KeypadEnter:  return .activateSelection
        case kVK_Escape:                        return .dismiss
        default:                                return nil
        }
    }
}
