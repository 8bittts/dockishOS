import AppKit
import ServiceManagement

/// Auto-launch on login via `SMAppService` (macOS 13+).
///
/// Only works when the binary is in a signed, notarized `.app` bundle that
/// macOS has registered as a Login Item. From `swift run` builds the call
/// will throw `notFound` — that's expected and silently ignored.
enum LoginItem {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    /// Returns true on success. Returns false (and leaves state unchanged)
    /// when running unbundled or when the user denied approval.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    static var statusDescription: String {
        switch status {
        case .notRegistered:    return "Not enabled"
        case .enabled:          return "Enabled — DockishOS will launch at login"
        case .requiresApproval: return "Pending approval in System Settings → General → Login Items"
        case .notFound:         return "Unavailable (run from a built `.app`)"
        @unknown default:       return "Unknown"
        }
    }
}
