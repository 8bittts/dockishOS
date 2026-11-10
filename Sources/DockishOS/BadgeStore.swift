import AppKit
import ApplicationServices
import Combine

/// Reads notification-badge strings (the little red number on Dock icons)
/// from the system Dock's accessibility tree and republishes them keyed by
/// bundle identifier. Polls only while the "Show notification badges"
/// setting is on.
@MainActor
final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    private static let pollInterval: TimeInterval = 2.5

    @Published private(set) var badges: [String: String] = [:]

    private var timer: Timer?
    private var settingObserver: AnyCancellable?

    private init() {
        // A `@Published` publisher sends its current value on subscription,
        // so this also applies the persisted setting at launch.
        settingObserver = SettingsStore.shared.$showNotificationBadges
            .removeDuplicates()
            .sink { [weak self] enabled in self?.setPolling(enabled) }
    }

    func badge(for bundleID: String?) -> String? {
        bundleID.flatMap { badges[$0] }
    }

    private func setPolling(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else {
            if !badges.isEmpty { badges = [:] }
            return
        }
        // Reading another app's accessibility tree needs the permission.
        Permissions.requestAccessibility()
        refresh()
        timer = Timer.repeating(every: Self.pollInterval) { [weak self] in self?.refresh() }
    }

    private func refresh() {
        let next = DockBadgeReader.read()
        if next != badges { badges = next }
    }
}

/// Stateless reader of the Dock's AX tree. Returns `[bundleID: badgeString]`,
/// or `[:]` on any failure (Dock not running, Accessibility not granted, Dock
/// layout changed in a future macOS release).
///
/// Apple does not expose another app's `NSDockTile.badgeLabel`, so this walks
/// the Dock process's AX hierarchy:
///
///     Dock (com.apple.dock)
///         └─ AXList
///             └─ AXApplicationDockItem (one per app icon)
///                 ├─ kAXURLAttribute   → file:///Applications/Foo.app
///                 └─ "AXStatusLabel"   → "12"   (the badge string)
///
/// `AXStatusLabel` is an undocumented attribute; the others are public
/// constants from `AXAttributeConstants.h`.
@MainActor
enum DockBadgeReader {
    static func read() -> [String: String] {
        guard let dock = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first else {
            Diagnostics.badges.debug("Dock process not found")
            return [:]
        }

        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        // Bound the synchronous AX round-trips so a hung Dock cannot block
        // the main run loop for the default messaging timeout.
        AXUIElementSetMessagingTimeout(dockElement, 0.5)
        let dockChildren: [AXUIElement] = AX.value(dockElement, kAXChildrenAttribute) ?? []
        guard
            let list = dockChildren.first(where: { AX.value($0, kAXRoleAttribute) == kAXListRole }),
            let items: [AXUIElement] = AX.value(list, kAXChildrenAttribute)
        else { return [:] }

        var badges: [String: String] = [:]
        for item in items where AX.value(item, kAXSubroleAttribute) == "AXApplicationDockItem" {
            guard
                let badge: String = AX.value(item, "AXStatusLabel"), !badge.isEmpty,
                let url: URL = AX.value(item, kAXURLAttribute), url.pathExtension == "app",
                let bundleID = Bundle(url: url)?.bundleIdentifier
            else { continue }
            badges[bundleID] = badge
        }
        return badges
    }
}
