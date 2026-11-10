import ApplicationServices

/// Thin wrappers around `AXUIElementCopyAttributeValue` so callers don't
/// have to repeat the `var raw: AnyObject? / err == .success / as? T`
/// dance. Each returns `nil` on any failure.
enum AX {
    /// Typed attribute extraction (works for arrays, strings, numbers, URLs —
    /// anything with a Foundation bridge).
    static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? T
    }

    /// AXUIElement extraction. Swift's `as?` doesn't reliably bridge a
    /// single CFTypeRef to `AXUIElement`, so we verify via CFTypeID first.
    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var raw: AnyObject?
        guard
            AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
            let raw,
            CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }
        return (raw as! AXUIElement)
    }
}
