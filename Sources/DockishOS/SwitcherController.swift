import AppKit
import Carbon.HIToolbox
import Combine
import DockishOSCore

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
        panel.present { visibleFrame, size in
            NSPoint(x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2)
        }
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

/// The switcher's panel. It reads the switcher's keys itself: the SwiftUI
/// content holds no keyboard focus, and AppKit would spend Tab on key-view
/// navigation.
final class SwitcherPanel: HUDPanel {
    enum Command {
        /// Move the selection by this many windows; negative moves back.
        case advance(Int)
        case activateSelection
        case dismiss
    }

    var onCommand: ((Command) -> Void)?

    init() {
        super.init(size: NSSize(width: 720, height: 200), accessibilityTitle: "App switcher")
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
