import AppKit

/// Read and toggle the system Dock's auto-hide preference. The Dock has
/// no public API for this — `defaults write com.apple.dock autohide`
/// followed by `killall Dock` is the long-standing standard approach.
enum DockHelper {
    /// Current system Dock autohide value.
    static var isAutoHideEnabled: Bool {
        let raw = run("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])
        return raw == "1" || raw.lowercased() == "true"
    }

    /// Set the Dock autohide value and restart the Dock to apply it.
    static func setAutoHide(_ enabled: Bool) {
        _ = run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", enabled ? "true" : "false"])
        _ = run("/usr/bin/killall", ["Dock"])
    }

    static func toggleAutoHide() {
        setAutoHide(!isAutoHideEnabled)
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let out = Pipe()
        task.standardOutput = out
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
