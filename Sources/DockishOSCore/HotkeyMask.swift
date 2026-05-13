public struct HotkeyModifierMask: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = HotkeyModifierMask(rawValue: 1 << 8)
    public static let shift = HotkeyModifierMask(rawValue: 1 << 9)
    public static let option = HotkeyModifierMask(rawValue: 1 << 11)
    public static let control = HotkeyModifierMask(rawValue: 1 << 12)
}

public enum HotkeyMask {
    public static func carbonMask(
        command: Bool,
        option: Bool,
        control: Bool,
        shift: Bool
    ) -> UInt32 {
        var mask = HotkeyModifierMask()
        if command { mask.insert(.command) }
        if option { mask.insert(.option) }
        if control { mask.insert(.control) }
        if shift { mask.insert(.shift) }
        return mask.rawValue
    }
}
