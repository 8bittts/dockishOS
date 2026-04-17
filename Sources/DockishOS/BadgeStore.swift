import AppKit
import ApplicationServices
import Combine

/// Reads notification-badge strings (the little red number on Dock icons)
/// from the system Dock's accessibility tree and republishes them keyed by
/// bundle identifier.
///
/// Apple does not expose another app's `NSDockTile.badgeLabel`, so we walk
/// the Dock process's AX hierarchy:
///
///     Dock (com.apple.dock)
///         └─ AXList ("the dock")
///             └─ AXApplicationDockItem... (one per app icon)
///                 ├─ kAXURLAttribute       → file:///Applications/Foo.app
///                 ├─ kAXTitleAttribute     → "Foo"
///                 └─ "AXStatusLabel"       → "12"   (the badge string)
///
/// `AXStatusLabel` is an undocumented attribute the Dock exposes — every
/// comparable tool (DockMate, DockShelf) uses it. The rest are public
/// attributes from `AXAttributeConstants.h`.
///
/// All AX calls happen on the main thread (Timer scheduled on main RL).
/// Apple's accessibility client docs require this.
final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    @Published private(set) var badges: [String: String] = [:]

    private var timer: Timer?
    private var settingsObserver: AnyCancellable?
    private let pollInterval: TimeInterval = 2.5

    private init() {
        settingsObserver = SettingsStore.shared.$showNotificationBadges
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.applyEnabled(enabled)
            }
        applyEnabled(SettingsStore.shared.showNotificationBadges)
    }

    func badge(for bundleID: String?) -> String? {
        guard let bid = bundleID else { return nil }
        return badges[bid]
    }

    private func applyEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        if enabled {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
                self?.refresh()
            }
        } else if !badges.isEmpty {
            badges = [:]
        }
    }

    private func refresh() {
        let next = DockBadgeReader.read()
        if next != badges { badges = next }
    }
}

/// Pure, stateless wrapper around the Dock's AX tree. Returns
/// `[bundleID: badgeString]`. Returns `[:]` on any failure (Dock not
/// running, AX permission revoked, Dock layout changed in a future macOS
/// release, etc.) — never throws, never crashes.
enum DockBadgeReader {
    static func read() -> [String: String] {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else { return [:] }

        let dockPID = dockApp.processIdentifier
        let dockAX = AXUIElementCreateApplication(dockPID)

        guard
            let dockChildren = copy(dockAX, kAXChildrenAttribute) as? [AXUIElement],
            let list = dockChildren.first,
            let icons = copy(list, kAXChildrenAttribute) as? [AXUIElement]
        else { return [:] }

        var result: [String: String] = [:]
        for icon in icons {
            guard
                let subrole = copy(icon, kAXSubroleAttribute) as? String,
                subrole == "AXApplicationDockItem"
            else { continue }

            guard
                let bundleID = bundleIdentifier(for: icon),
                let badge = copy(icon, "AXStatusLabel" as CFString) as? String,
                !badge.isEmpty
            else { continue }

            result[bundleID] = badge
        }
        return result
    }

    private static func bundleIdentifier(for icon: AXUIElement) -> String? {
        let raw = copy(icon, kAXURLAttribute)
        let url: URL?
        if let u = raw as? URL { url = u }
        else if let n = raw as? NSURL { url = n as URL }
        else { url = nil }
        guard let url, url.pathExtension == "app" else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    private static func copy(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        return err == .success ? value : nil
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        copy(element, attribute as CFString)
    }
}
