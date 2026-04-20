import AppKit
import ApplicationServices

enum Permissions {
    private static let accessibilityPromptedKey = "DockishOS.hasPromptedForAccessibility"

    private static var hasPromptedForAccessibility: Bool {
        get { UserDefaults.standard.bool(forKey: accessibilityPromptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessibilityPromptedKey) }
    }

    /// Returns true if Accessibility is granted. Pass `prompt: true` to surface
    /// the system dialog (Settings → Privacy → Accessibility). We only allow
    /// DockishOS to trigger that prompt once across launches; after that the
    /// app degrades gracefully until the user grants access in System Settings.
    @discardableResult
    static func ensureAccessibility(prompt: Bool = false) -> Bool {
        if isAccessibilityGranted {
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

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityFromSettings() {
        hasPromptedForAccessibility = false
        _ = ensureAccessibility(prompt: true)
        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Called early; we only check (don't prompt) so the bar can render
    /// even before the user grants Accessibility.
    static func warmup() {
        _ = ensureAccessibility(prompt: false)
    }
}
