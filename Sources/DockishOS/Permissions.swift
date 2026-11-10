import AppKit
// The SDK declares `kAXTrustedCheckOptionPrompt` as a mutable global.
@preconcurrency import ApplicationServices

@MainActor
enum Permissions {
    private static let promptedKey = "DockishOS.hasPromptedForAccessibility"

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true if Accessibility is granted. When it is not, shows the
    /// system prompt (Settings → Privacy → Accessibility) — but only once
    /// across launches. After that the app degrades gracefully until the user
    /// grants access in System Settings.
    @discardableResult
    static func requestAccessibility() -> Bool {
        if isAccessibilityGranted { return true }
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return false }
        UserDefaults.standard.set(true, forKey: promptedKey)
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptOption: true] as CFDictionary)
    }

    /// The Settings button: prompts again even if the user dismissed the
    /// prompt before, then opens the Accessibility pane.
    static func requestAccessibilityFromSettings() {
        UserDefaults.standard.set(false, forKey: promptedKey)
        requestAccessibility()
        if let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(pane)
        }
    }
}
