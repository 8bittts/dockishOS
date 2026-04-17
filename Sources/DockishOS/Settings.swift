import AppKit
import Combine

/// Three discrete bar sizes. Chosen instead of a slider so the layout is
/// always pixel-honest and easy to test.
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
        static let showChipTitles  = "DockishOS.showChipTitles"
        static let showPinnedRow   = "DockishOS.showPinnedRow"
    }

    @Published var barSize: BarSize {
        didSet {
            guard barSize != oldValue else { return }
            UserDefaults.standard.set(barSize.rawValue, forKey: Key.barSize)
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

    private init() {
        let raw = UserDefaults.standard.string(forKey: Key.barSize) ?? BarSize.medium.rawValue
        self.barSize = BarSize(rawValue: raw) ?? .medium
        self.showChipTitles = (UserDefaults.standard.object(forKey: Key.showChipTitles) as? Bool) ?? true
        self.showPinnedRow  = (UserDefaults.standard.object(forKey: Key.showPinnedRow)  as? Bool) ?? true
    }
}
