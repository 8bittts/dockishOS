public struct SettingsSnapshot: Codable, Equatable, Sendable {
    public var barSize: String
    public var barPosition: String
    public var showChipTitles: Bool
    public var showPinnedRow: Bool
    public var barCollapsed: Bool
    public var collapsedTabPosition: CollapsedTabPlacement
    public var disabledScreenUUIDs: [String]
    public var groupWindowsByApp: Bool
    public var showNotificationBadges: Bool

    public init(
        barSize: String,
        barPosition: String,
        showChipTitles: Bool,
        showPinnedRow: Bool,
        barCollapsed: Bool,
        collapsedTabPosition: CollapsedTabPlacement,
        disabledScreenUUIDs: [String],
        groupWindowsByApp: Bool,
        showNotificationBadges: Bool
    ) {
        self.barSize = barSize
        self.barPosition = barPosition
        self.showChipTitles = showChipTitles
        self.showPinnedRow = showPinnedRow
        self.barCollapsed = barCollapsed
        self.collapsedTabPosition = collapsedTabPosition
        self.disabledScreenUUIDs = disabledScreenUUIDs
        self.groupWindowsByApp = groupWindowsByApp
        self.showNotificationBadges = showNotificationBadges
    }
}
