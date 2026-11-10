import AppKit
import ApplicationServices
import DockishOSCore

/// Bridges a CGWindowID to its AX element so we can raise or close a
/// *specific* window (not just its owning app).
@MainActor
enum WindowControl {
    /// Private HIServices call that maps an AX window element to its CGWindowID.
    private static let getWindowID = privateSymbol(
        "_AXUIElementGetWindow",
        as: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError).self
    )

    /// Activate the owning app and raise the specific window.
    /// Falls back to app-only activation if Accessibility is denied.
    static func raise(_ window: WindowInfo) {
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            AppActivation.activate(app)
        }
        guard Permissions.requestAccessibility() else {
            Diagnostics.permissions.debug("Accessibility denied — falling back to app activation")
            return
        }
        guard let axWindow = axWindow(for: window) else { return }
        let raiseError = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        if raiseError != .success {
            Diagnostics.windows.debug("raise action failed: \(raiseError.rawValue, privacy: .public)")
        }
        let mainError = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        if mainError != .success {
            Diagnostics.windows.debug("set-main failed: \(mainError.rawValue, privacy: .public)")
        }
    }

    /// Close a specific window via the AX close button.
    static func close(_ window: WindowInfo) {
        guard
            Permissions.requestAccessibility(),
            let axWindow = axWindow(for: window),
            let closeButton = AX.element(axWindow, kAXCloseButtonAttribute)
        else { return }
        let pressError = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        if pressError != .success {
            Diagnostics.windows.debug("close press failed: \(pressError.rawValue, privacy: .public)")
        }
    }

    /// Walk the AX windows of the owning app and find the one whose
    /// CGWindowID matches our target.
    private static func axWindow(for window: WindowInfo) -> AXUIElement? {
        guard let getWindowID else {
            Diagnostics.windows.fault("_AXUIElementGetWindow unavailable; window-specific controls disabled")
            return nil
        }
        let axApp = AXUIElementCreateApplication(window.pid)
        // Bound the synchronous AX round-trips so a hung target app cannot
        // block the main run loop for the ~6s default AX messaging timeout.
        AXUIElementSetMessagingTimeout(axApp, 0.5)
        let axWindows: [AXUIElement] = AX.value(axApp, kAXWindowsAttribute) ?? []
        return axWindows.first { axWindow in
            var id: CGWindowID = 0
            return getWindowID(axWindow, &id) == .success && id == window.id
        }
    }
}
