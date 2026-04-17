import Foundation
import os

/// Unified `os.Logger` subsystem for DockishOS. View live logs with:
///
///     log stream --process DockishOS --info --debug
///     log show --predicate 'subsystem == "com.8bittts.dockishos"' --last 5m
///
/// Use these sparingly for lifecycle events and unexpected failures —
/// don't log on every polling tick.
enum Diagnostics {
    private static let subsystem = "com.8bittts.dockishos"

    static let lifecycle   = Logger(subsystem: subsystem, category: "lifecycle")
    static let bar         = Logger(subsystem: subsystem, category: "bar")
    static let windows     = Logger(subsystem: subsystem, category: "windows")
    static let spaces      = Logger(subsystem: subsystem, category: "spaces")
    static let badges      = Logger(subsystem: subsystem, category: "badges")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let updater     = Logger(subsystem: subsystem, category: "updater")
}
