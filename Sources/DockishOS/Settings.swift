import AppKit
import Combine
import DockishOSCore

enum BarPosition: String, CaseIterable, Identifiable {
    case top, bottom

    var id: String { rawValue }
    var displayName: String { self == .top ? "Top" : "Bottom" }
}

/// Three discrete bar sizes. Chosen instead of a slider so the layout is
/// always pixel-honest and easy to test.
enum BarSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    var height: CGFloat {
        switch self {
        case .small:  return 44
        case .medium: return 56
        case .large:  return 72
        }
    }

    /// Height of a window chip, and the side of a pinned-app chip.
    var chipHeight: CGFloat {
        switch self {
        case .small:  return 26
        case .medium: return 34
        case .large:  return 44
        }
    }

    var chipIconSize: CGFloat {
        switch self {
        case .small:  return 18
        case .medium: return 22
        case .large:  return 28
        }
    }
}

extension CollapsedTabPosition {
    var displayName: String {
        switch self {
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

extension Notification.Name {
    /// Posted when a setting that changes bar frames or the set of bars
    /// changes: size, position, collapsed tab corner, per-display visibility.
    static let dockishBarLayoutDidChange = Notification.Name("DockishOS.BarLayoutDidChange")
    /// Posted when the bar collapses or expands, so each bar animates.
    static let dockishBarCollapseDidChange = Notification.Name("DockishOS.BarCollapseDidChange")
    /// Posted when either global hotkey changes and must be registered again.
    static let dockishHotkeyDidChange = Notification.Name("DockishOS.HotkeyDidChange")
}

/// Persistent app-wide preferences. UserDefaults-backed.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let barSize = "DockishOS.barSize"
        static let barPosition = "DockishOS.barPosition"
        static let showChipTitles = "DockishOS.showChipTitles"
        static let showPinnedRow = "DockishOS.showPinnedRow"
        static let barCollapsed = "DockishOS.barCollapsed"
        static let collapsedTabPosition = "DockishOS.collapsedTabPosition"
        static let disabledScreens = "DockishOS.disabledScreens"
        static let launcherHotkey = "DockishOS.launcherHotkey"
        static let switcherHotkey = "DockishOS.switcherHotkey"
        static let groupWindowsByApp = "DockishOS.groupByApp"
        static let showNotificationBadges = "DockishOS.showNotificationBadges"
    }

    private let defaults = UserDefaults.standard

    @Published var barSize: BarSize {
        didSet {
            guard barSize != oldValue else { return }
            defaults.set(barSize.rawValue, forKey: Key.barSize)
            post(.dockishBarLayoutDidChange)
        }
    }

    @Published var barPosition: BarPosition {
        didSet {
            guard barPosition != oldValue else { return }
            defaults.set(barPosition.rawValue, forKey: Key.barPosition)
            post(.dockishBarLayoutDidChange)
        }
    }

    @Published var showChipTitles: Bool {
        didSet {
            guard showChipTitles != oldValue else { return }
            defaults.set(showChipTitles, forKey: Key.showChipTitles)
        }
    }

    @Published var showPinnedRow: Bool {
        didSet {
            guard showPinnedRow != oldValue else { return }
            defaults.set(showPinnedRow, forKey: Key.showPinnedRow)
        }
    }

    @Published var barCollapsed: Bool {
        didSet {
            guard barCollapsed != oldValue else { return }
            defaults.set(barCollapsed, forKey: Key.barCollapsed)
            post(.dockishBarCollapseDidChange)
        }
    }

    @Published var collapsedTabPosition: CollapsedTabPosition {
        didSet {
            guard collapsedTabPosition != oldValue else { return }
            defaults.set(collapsedTabPosition.rawValue, forKey: Key.collapsedTabPosition)
            post(.dockishBarLayoutDidChange)
        }
    }

    /// Displays the user turned the bar off for. Change it through
    /// `setScreen(_:enabled:)`.
    @Published private(set) var disabledScreenUUIDs: Set<String> {
        didSet {
            guard disabledScreenUUIDs != oldValue else { return }
            defaults.set(Array(disabledScreenUUIDs), forKey: Key.disabledScreens)
            post(.dockishBarLayoutDidChange)
        }
    }

    @Published var launcherHotkey: Hotkey {
        didSet {
            guard launcherHotkey != oldValue else { return }
            save(launcherHotkey, forKey: Key.launcherHotkey)
        }
    }

    @Published var switcherHotkey: Hotkey {
        didSet {
            guard switcherHotkey != oldValue else { return }
            save(switcherHotkey, forKey: Key.switcherHotkey)
        }
    }

    @Published var groupWindowsByApp: Bool {
        didSet {
            guard groupWindowsByApp != oldValue else { return }
            defaults.set(groupWindowsByApp, forKey: Key.groupWindowsByApp)
        }
    }

    @Published var showNotificationBadges: Bool {
        didSet {
            guard showNotificationBadges != oldValue else { return }
            defaults.set(showNotificationBadges, forKey: Key.showNotificationBadges)
        }
    }

    func isScreenEnabled(_ screen: NSScreen) -> Bool {
        !disabledScreenUUIDs.contains(screen.displayUUID)
    }

    /// Turns the bar on or off for one display. Refuses to turn off the last
    /// connected display that still shows a bar.
    func setScreen(_ displayUUID: String, enabled: Bool) {
        var disabled = disabledScreenUUIDs
        if enabled {
            disabled.remove(displayUUID)
        } else {
            disabled.insert(displayUUID)
        }
        let connected = Set(NSScreen.screens.map(\.displayUUID))
        guard connected.isEmpty || !connected.isSubset(of: disabled) else { return }
        disabledScreenUUIDs = disabled
    }

    private init() {
        defaults.register(defaults: [
            Key.showChipTitles: true,
            Key.showPinnedRow: true,
        ])
        barSize = defaults.string(forKey: Key.barSize).flatMap(BarSize.init) ?? .medium
        barPosition = defaults.string(forKey: Key.barPosition).flatMap(BarPosition.init) ?? .bottom
        showChipTitles = defaults.bool(forKey: Key.showChipTitles)
        showPinnedRow = defaults.bool(forKey: Key.showPinnedRow)
        barCollapsed = defaults.bool(forKey: Key.barCollapsed)
        collapsedTabPosition = defaults.string(forKey: Key.collapsedTabPosition)
            .flatMap(CollapsedTabPosition.init) ?? .bottomRight
        disabledScreenUUIDs = Set(defaults.stringArray(forKey: Key.disabledScreens) ?? [])
        launcherHotkey = Self.loadHotkey(from: defaults, forKey: Key.launcherHotkey) ?? .launcherDefault
        switcherHotkey = Self.loadHotkey(from: defaults, forKey: Key.switcherHotkey) ?? .switcherDefault
        groupWindowsByApp = defaults.bool(forKey: Key.groupWindowsByApp)
        showNotificationBadges = defaults.bool(forKey: Key.showNotificationBadges)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func save(_ hotkey: Hotkey, forKey key: String) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: key)
        }
        post(.dockishHotkeyDidChange)
    }

    private static func loadHotkey(from defaults: UserDefaults, forKey key: String) -> Hotkey? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) }
    }
}
