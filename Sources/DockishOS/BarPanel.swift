import AppKit

final class BarPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
    }

    /// VoiceOver and Full Keyboard Access need a key window to reach chips.
    /// `.nonactivatingPanel` still keeps mouse clicks from activating the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
