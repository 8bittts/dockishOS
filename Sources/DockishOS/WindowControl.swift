import AppKit
import ApplicationServices
import Darwin

/// Bridges a CGWindowID to its AX element so we can raise / close / focus
/// a *specific* window (not just its owning app).
///
enum WindowControl {
    private typealias AXUIElementGetWindowFunction = @convention(c) (
        AXUIElement,
        UnsafeMutablePointer<CGWindowID>
    ) -> AXError

    private static let getWindowID: AXUIElementGetWindowFunction? = {
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = dlsym(handle, "_AXUIElementGetWindow") else {
            Diagnostics.windows.fault("_AXUIElementGetWindow unavailable; window-specific controls disabled")
            return nil
        }
        return unsafeBitCast(symbol, to: AXUIElementGetWindowFunction.self)
    }()

    /// Activate the owning app and raise the specific window.
    /// Falls back to app-only activation if Accessibility is denied.
    static func raise(_ window: WindowInfo) {
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            AppActivation.activate(app)
        }
        guard Permissions.ensureAccessibility(prompt: true) else {
            Diagnostics.permissions.debug("Accessibility denied — falling back to app activation")
            return
        }
        guard let axWin = axWindow(for: window) else { return }
        AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axWin, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    /// Close a specific window via the AX close button.
    static func close(_ window: WindowInfo) {
        guard Permissions.ensureAccessibility(prompt: true), let axWin = axWindow(for: window) else { return }
        guard let button = AX.element(axWin, kAXCloseButtonAttribute as CFString) else { return }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }

    /// Walk the AX windows of the owning app and find the one whose
    /// CGWindowID matches our target.
    private static func axWindow(for window: WindowInfo) -> AXUIElement? {
        guard let getWindowID else { return nil }
        let axApp = AXUIElementCreateApplication(window.pid)
        guard let axWindows: [AXUIElement] = AX.value(axApp, kAXWindowsAttribute as CFString) else {
            return nil
        }
        for ax in axWindows {
            var id: CGWindowID = 0
            if getWindowID(ax, &id) == .success, id == window.id {
                return ax
            }
        }
        return nil
    }
}
