import AppKit
import ApplicationServices

enum Permissions {
    /// Returns true if Accessibility is granted. Pass `prompt: true` to surface
    /// the system dialog (Settings → Privacy → Accessibility).
    @discardableResult
    static func ensureAccessibility(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Called early; we only check (don't prompt) so the bar can render
    /// even before the user grants permissions.
    static func warmup() {
        _ = ensureAccessibility(prompt: false)
    }
}
