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

    /// Side of every app icon on the bar, in window chips and pinned chips alike.
    var chipIconSize: CGFloat {
        switch self {
        case .small:  return 24
        case .medium: return 28
        case .large:  return 36
        }
    }

    /// Side of the brand mark in the collapse button and the edge tab.
    var controlIconSize: CGFloat {
        switch self {
        case .small:  return 16
        case .medium: return 20
        case .large:  return 24
        }
    }

    /// Height of a window chip: its icon plus `Spacing.xs` above and below.
    var chipHeight: CGFloat {
        chipIconSize + Spacing.xs * 2
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
    /// Posted when the switcher hotkey changes and must be registered again.
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

    @Published var switcherHotkey: Hotkey {
        didSet {
            guard switcherHotkey != oldValue else { return }
            if let data = try? JSONEncoder().encode(switcherHotkey) {
                defaults.set(data, forKey: Key.switcherHotkey)
            }
            post(.dockishHotkeyDidChange)
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
        switcherHotkey = defaults.data(forKey: Key.switcherHotkey)
            .flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) } ?? .switcherDefault
        groupWindowsByApp = defaults.bool(forKey: Key.groupWindowsByApp)
        showNotificationBadges = defaults.bool(forKey: Key.showNotificationBadges)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
