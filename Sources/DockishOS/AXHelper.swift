import AppKit
import ApplicationServices

/// Thin wrappers around `AXUIElementCopyAttributeValue` so callers don't
/// have to repeat the `var raw: AnyObject? / err == .success / as? T`
/// dance. Returns `nil` on any failure.
///
/// All AX calls must be made on the main thread per Apple's accessibility
/// client documentation.
enum AX {
    /// Typed attribute extraction (works for arrays, strings, numbers,
    /// dictionaries — anything with a Foundation bridge).
    static func value<T>(_ element: AXUIElement, _ attribute: CFString) -> T? {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &raw) == .success else { return nil }
        return raw as? T
    }

    static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        value(element, attribute as CFString)
    }

    /// AXUIElement extraction. Swift's `as?` doesn't reliably bridge a
    /// single CFTypeRef to `AXUIElement`, so we verify via CFTypeID first.
    static func element(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var raw: AnyObject?
        guard
            AXUIElementCopyAttributeValue(element, attribute, &raw) == .success,
            let raw,
            CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }
        return (raw as! AXUIElement)
    }

    /// URL attribute (e.g. `kAXURLAttribute` on Dock items). Bridges both
    /// `URL` and `NSURL` returns.
    static func url(_ element: AXUIElement, _ attribute: CFString) -> URL? {
        var raw: AnyObject?
        guard
            AXUIElementCopyAttributeValue(element, attribute, &raw) == .success,
            let raw
        else { return nil }
        if let u = raw as? URL { return u }
        if let n = raw as? NSURL { return n as URL }
        return nil
    }
}
