import AppKit
import Carbon.HIToolbox

/// User-configurable global hotkey for the launcher. Stored as Carbon
/// keyCode + modifier mask (matches `RegisterEventHotKey`'s ABI) plus a
/// pre-rendered display string captured at record time.
struct LauncherHotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String

    static let `default` = LauncherHotkey(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey),
        displayString: "⌥ Space"
    )

    /// Convert NSEvent flags to Carbon's modifier bitmask used by
    /// `RegisterEventHotKey`.
    static func carbonMask(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command)  { mask |= UInt32(cmdKey) }
        if flags.contains(.option)   { mask |= UInt32(optionKey) }
        if flags.contains(.control)  { mask |= UInt32(controlKey) }
        if flags.contains(.shift)    { mask |= UInt32(shiftKey) }
        return mask
    }

    /// Build the user-visible string ("⌥⌘ K", "⌃ Space", …) from an event.
    static func displayString(for event: NSEvent) -> String {
        var s = ""
        let f = event.modifierFlags
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option)  { s += "⌥" }
        if f.contains(.shift)   { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        if !s.isEmpty { s += " " }
        s += keyName(for: Int(event.keyCode), fallback: event.charactersIgnoringModifiers ?? "?")
        return s
    }

    /// Render the persisted hotkey for display (used when the recorder
    /// shows the current binding before recording starts).
    static func keyName(for keyCode: Int, fallback: String) -> String {
        switch keyCode {
        case kVK_Space:        return "Space"
        case kVK_Return:       return "Return"
        case kVK_Tab:          return "Tab"
        case kVK_Escape:       return "Esc"
        case kVK_Delete:       return "Delete"
        case kVK_ForwardDelete:return "Fwd Delete"
        case kVK_LeftArrow:    return "←"
        case kVK_RightArrow:   return "→"
        case kVK_UpArrow:      return "↑"
        case kVK_DownArrow:    return "↓"
        case kVK_F1:           return "F1"
        case kVK_F2:           return "F2"
        case kVK_F3:           return "F3"
        case kVK_F4:           return "F4"
        case kVK_F5:           return "F5"
        case kVK_F6:           return "F6"
        case kVK_F7:           return "F7"
        case kVK_F8:           return "F8"
        case kVK_F9:           return "F9"
        case kVK_F10:          return "F10"
        case kVK_F11:          return "F11"
        case kVK_F12:          return "F12"
        case kVK_F13:          return "F13"
        case kVK_F14:          return "F14"
        case kVK_F15:          return "F15"
        default:
            return fallback.uppercased()
        }
    }
}

/// NSView that records the next key chord pressed while focused.
final class HotkeyRecorderView: NSView {
    var hotkey: LauncherHotkey = .default {
        didSet { needsDisplay = true }
    }
    var onChange: ((LauncherHotkey) -> Void)?

    private var recording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 26) }

    override func mouseDown(with event: NSEvent) {
        recording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }

        // Esc cancels recording without changing the binding.
        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            window?.makeFirstResponder(nil)
            return
        }

        let mask = LauncherHotkey.carbonMask(from: event.modifierFlags)
        // Require at least one non-shift modifier so the chord doesn't
        // collide with normal typing.
        let nonShift = mask & ~UInt32(shiftKey)
        guard nonShift != 0 else { return }

        let new = LauncherHotkey(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: mask,
            displayString: LauncherHotkey.displayString(for: event)
        )
        hotkey = new
        onChange?(new)
        recording = false
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let label = recording ? "Press shortcut…" : hotkey.displayString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: recording
                ? NSColor.controlAccentColor
                : NSColor.labelColor,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        ))
    }
}
