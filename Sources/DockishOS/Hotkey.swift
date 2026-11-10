import AppKit
import Carbon.HIToolbox

/// The user-configurable global hotkey that opens the app switcher. Stored as Carbon key code + modifier
/// mask (matches `RegisterEventHotKey`'s ABI) plus a pre-rendered display
/// string captured at record time.
struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String

    static let switcherDefault = Hotkey(
        keyCode: UInt32(kVK_Tab),
        carbonModifiers: UInt32(optionKey),
        displayString: "⌥ Tab"
    )
}

extension Hotkey {
    /// The chord in a key-down event. Returns nil unless the chord holds ⌃, ⌥
    /// or ⌘, so a hotkey cannot collide with normal typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        let modifiers: [(flag: NSEvent.ModifierFlags, carbonMask: Int, symbol: String)] = [
            (.control, controlKey, "⌃"),
            (.option, optionKey, "⌥"),
            (.shift, shiftKey, "⇧"),
            (.command, cmdKey, "⌘"),
        ]
        let held = modifiers.filter { flags.contains($0.flag) }
        guard held.contains(where: { $0.flag != .shift }) else { return nil }

        self.init(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: held.reduce(0) { $0 | UInt32($1.carbonMask) },
            displayString: held.map(\.symbol).joined() + " " + Self.keyName(for: event)
        )
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:         return "Space"
        case kVK_Return:        return "Return"
        case kVK_Tab:           return "Tab"
        case kVK_Escape:        return "Esc"
        case kVK_Delete:        return "Delete"
        case kVK_ForwardDelete: return "Fwd Delete"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        case kVK_UpArrow:       return "↑"
        case kVK_DownArrow:     return "↓"
        case kVK_F1:            return "F1"
        case kVK_F2:            return "F2"
        case kVK_F3:            return "F3"
        case kVK_F4:            return "F4"
        case kVK_F5:            return "F5"
        case kVK_F6:            return "F6"
        case kVK_F7:            return "F7"
        case kVK_F8:            return "F8"
        case kVK_F9:            return "F9"
        case kVK_F10:           return "F10"
        case kVK_F11:           return "F11"
        case kVK_F12:           return "F12"
        case kVK_F13:           return "F13"
        case kVK_F14:           return "F14"
        case kVK_F15:           return "F15"
        default:                return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}
