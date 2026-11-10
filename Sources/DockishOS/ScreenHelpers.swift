import AppKit

extension NSScreen {
    /// Screen containing the given point in screen coordinates, falling
    /// back to `NSScreen.main`. Returns `nil` only if there are *no*
    /// displays connected (headless or every display unplugged mid-flight).
    static func containing(_ point: NSPoint) -> NSScreen? {
        screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? .main
    }

    /// Stable identifier for the physical display, the same string the window
    /// server uses to key per-display Spaces. Falls back to "Main".
    var displayUUID: String {
        guard
            let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return "Main" }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
