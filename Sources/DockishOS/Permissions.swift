import AppKit
import ApplicationServices

enum Permissions {
    private static var hasPromptedForAccessibility = false

    /// Returns true if Accessibility is granted. Pass `prompt: true` to surface
    /// the system dialog (Settings → Privacy → Accessibility).
    @discardableResult
    static func ensureAccessibility(prompt: Bool = false) -> Bool {
        if AXIsProcessTrusted() {
            hasPromptedForAccessibility = false
            return true
        }

        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let shouldPrompt = prompt && !hasPromptedForAccessibility
        if shouldPrompt {
            hasPromptedForAccessibility = true
        }
        let opts = [key: shouldPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Called early; we only check (don't prompt) so the bar can render
    /// even before the user grants Accessibility.
    static func warmup() {
        _ = ensureAccessibility(prompt: false)
    }
}
