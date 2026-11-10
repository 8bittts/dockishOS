import ServiceManagement

/// Auto-launch on login via `SMAppService`.
///
/// Only works when the binary is in a signed, notarized `.app` bundle that
/// macOS has registered as a Login Item. From `swift run` builds the call
/// throws and the status reads `notFound`.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the login item. A failure leaves the state
    /// unchanged, so callers re-read `isEnabled` afterwards.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Diagnostics.lifecycle.error(
                "login item \(enabled ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:          return "DockishOS opens when you log in."
        case .requiresApproval: return "Approve DockishOS in System Settings > General > Login Items."
        case .notFound:         return "macOS does not list this copy of DockishOS as a login item."
        case .notRegistered:    return "DockishOS does not open when you log in."
        @unknown default:       return ""
        }
    }
}
