import AppKit
import SwiftUI

/// Borderless floating panel that takes key focus without activating the
/// app: the launcher and the app switcher.
///
/// `.nonactivatingPanel` is what makes these panels reliable. The app the
/// user was in stays active, so nothing has to bring DockishOS forward on
/// open or hand focus back on close.
class HUDPanel: NSPanel {
    private let spokenTitle: String

    /// - Parameter accessibilityTitle: Read by VoiceOver, because a borderless
    ///   panel has no visible title.
    init(size: NSSize, accessibilityTitle: String) {
        spokenTitle = accessibilityTitle
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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

    /// Installs SwiftUI content that fills the panel. The panel keeps the
    /// size it was created with: left to its default sizing options, the
    /// hosting view resizes the window to the content's smallest size, which
    /// collapses the launcher to its search field and hides the results.
    func setContent(_ view: some View) {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func accessibilityTitle() -> String? { spokenTitle }

    /// Shows the panel on the screen under the pointer and gives it key focus.
    /// `origin` places a panel of the given size inside that screen's visible frame.
    func present(origin: (_ visibleFrame: NSRect, _ size: NSSize) -> NSPoint) {
        if let screen = NSScreen.containing(NSEvent.mouseLocation) {
            setFrameOrigin(origin(screen.visibleFrame, frame.size))
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
}
