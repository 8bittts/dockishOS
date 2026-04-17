import AppKit

extension NSScreen {
    /// Screen containing the given point in screen coordinates, falling
    /// back to `NSScreen.main`. Returns `nil` only if there are *no*
    /// displays connected (headless or every display unplugged mid-flight).
    /// Callers should guard `nil` rather than force-unwrap downstream.
    static func containing(_ point: NSPoint) -> NSScreen? {
        screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? .main
    }
}
