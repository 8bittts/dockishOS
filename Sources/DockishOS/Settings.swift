import AppKit
import Carbon.HIToolbox
import Combine

/// Three discrete bar sizes. Chosen instead of a slider so the layout is
/// always pixel-honest and easy to test.
enum BarPosition: String, CaseIterable, Codable, Identifiable {
    case top, bottom
    var id: String { rawValue }
    var displayName: String { self == .top ? "Top" : "Bottom" }
}

enum BarSize: String, CaseIterable, Codable, Identifiable {
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

    var spaceChipSize: CGFloat {
        switch self {
        case .small:  return 20
        case .medium: return 24
        case .large:  return 30
        }
    }

    var pinnedChipSize: CGFloat {
        switch self {
        case .small:  return 26
        case .medium: return 34
        case .large:  return 44
        }
    }
}

extension Notification.Name {
    /// Posted when any setting that requires bars to be rebuilt changes
    /// (currently: bar size). The AppDelegate listens and calls
    /// `rebuildBars()`.
    static let dockishBarLayoutDidChange = Notification.Name("DockishOS.BarLayoutDidChange")
}

/// Persistent app-wide preferences. UserDefaults-backed.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private struct Key {
        static let barSize         = "DockishOS.barSize"
        static let barPosition     = "DockishOS.barPosition"
        static let showChipTitles  = "DockishOS.showChipTitles"
        static let showPinnedRow   = "DockishOS.showPinnedRow"
        static let disabledScreens = "DockishOS.disabledScreens"
        static let launcherHotkey  = "DockishOS.launcherHotkey"
        static let switcherHotkey  = "DockishOS.switcherHotkey"
        static let groupByApp      = "DockishOS.groupByApp"
        static let notifBadges     = "DockishOS.showNotificationBadges"
    }

    @Published var barSize: BarSize {
        didSet {
            guard barSize != oldValue else { return }
            UserDefaults.standard.set(barSize.rawValue, forKey: Key.barSize)
            NotificationCenter.default.post(name: .dockishBarLayoutDidChange, object: nil)
        }
    }

    @Published var barPosition: BarPosition {
        didSet {
            guard barPosition != oldValue else { return }
            UserDefaults.standard.set(barPosition.rawValue, forKey: Key.barPosition)
            NotificationCenter.default.post(name: .dockishBarLayoutDidChange, object: nil)
        }
    }

    @Published var showChipTitles: Bool {
        didSet {
            guard showChipTitles != oldValue else { return }
            UserDefaults.standard.set(showChipTitles, forKey: Key.showChipTitles)
        }
    }

    @Published var showPinnedRow: Bool {
        didSet {
            guard showPinnedRow != oldValue else { return }
            UserDefaults.standard.set(showPinnedRow, forKey: Key.showPinnedRow)
        }
    }

    @Published var disabledScreenUUIDs: Set<String> {
        didSet {
            guard disabledScreenUUIDs != oldValue else { return }
            // Refuse to disable every connected display — the user would
            // lose access to the bar with no recovery UI.
            let connected = Set(NSScreen.screens.map { SpacesAPI.displayUUID(for: $0) })
            if !connected.isEmpty, connected.isSubset(of: disabledScreenUUIDs) {
                disabledScreenUUIDs = oldValue
                return
            }
            UserDefaults.standard.set(Array(disabledScreenUUIDs), forKey: Key.disabledScreens)
            NotificationCenter.default.post(name: .dockishBarLayoutDidChange, object: nil)
        }
    }

    @Published var launcherHotkey: LauncherHotkey {
        didSet {
            guard launcherHotkey != oldValue else { return }
            if let data = try? JSONEncoder().encode(launcherHotkey) {
                UserDefaults.standard.set(data, forKey: Key.launcherHotkey)
            }
            NotificationCenter.default.post(name: .dockishHotkeyDidChange, object: nil)
        }
    }

    @Published var switcherHotkey: LauncherHotkey {
        didSet {
            guard switcherHotkey != oldValue else { return }
            if let data = try? JSONEncoder().encode(switcherHotkey) {
                UserDefaults.standard.set(data, forKey: Key.switcherHotkey)
            }
            NotificationCenter.default.post(name: .dockishHotkeyDidChange, object: nil)
        }
    }

    @Published var groupWindowsByApp: Bool {
        didSet {
            guard groupWindowsByApp != oldValue else { return }
            UserDefaults.standard.set(groupWindowsByApp, forKey: Key.groupByApp)
        }
    }

    @Published var showNotificationBadges: Bool {
        didSet {
            guard showNotificationBadges != oldValue else { return }
            UserDefaults.standard.set(showNotificationBadges, forKey: Key.notifBadges)
        }
    }

    func isScreenEnabled(_ screen: NSScreen) -> Bool {
        !disabledScreenUUIDs.contains(SpacesAPI.displayUUID(for: screen))
    }

    private init() {
        let rawSize = UserDefaults.standard.string(forKey: Key.barSize) ?? BarSize.medium.rawValue
        self.barSize = BarSize(rawValue: rawSize) ?? .medium
        let rawPos = UserDefaults.standard.string(forKey: Key.barPosition) ?? BarPosition.bottom.rawValue
        self.barPosition = BarPosition(rawValue: rawPos) ?? .bottom
        self.showChipTitles = (UserDefaults.standard.object(forKey: Key.showChipTitles) as? Bool) ?? true
        self.showPinnedRow  = (UserDefaults.standard.object(forKey: Key.showPinnedRow)  as? Bool) ?? true
        let disabled = UserDefaults.standard.stringArray(forKey: Key.disabledScreens) ?? []
        self.disabledScreenUUIDs = Set(disabled)
        if let data = UserDefaults.standard.data(forKey: Key.launcherHotkey),
           let hk = try? JSONDecoder().decode(LauncherHotkey.self, from: data) {
            self.launcherHotkey = hk
        } else {
            self.launcherHotkey = .default
        }
        if let data = UserDefaults.standard.data(forKey: Key.switcherHotkey),
           let hk = try? JSONDecoder().decode(LauncherHotkey.self, from: data) {
            self.switcherHotkey = hk
        } else {
            self.switcherHotkey = LauncherHotkey(
                keyCode: UInt32(kVK_Tab),
                carbonModifiers: UInt32(optionKey),
                displayString: "⌥ Tab"
            )
        }
        self.groupWindowsByApp = (UserDefaults.standard.object(forKey: Key.groupByApp) as? Bool) ?? false
        self.showNotificationBadges = (UserDefaults.standard.object(forKey: Key.notifBadges) as? Bool) ?? false
    }
}

extension Notification.Name {
    /// Posted when the launcher hotkey changes — AppDelegate re-registers
    /// the global Carbon hotkey.
    static let dockishHotkeyDidChange = Notification.Name("DockishOS.HotkeyDidChange")
}
