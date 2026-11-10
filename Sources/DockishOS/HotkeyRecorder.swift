import AppKit
import Carbon.HIToolbox
import SwiftUI

/// SwiftUI field that shows a hotkey and records a replacement.
struct HotkeyRecorder: NSViewRepresentable {
    let title: String
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.onChange = { hotkey = $0 }
        return view
    }

    func updateNSView(_ view: HotkeyRecorderView, context: Context) {
        view.hotkey = hotkey
        view.recorderLabel = title
    }
}

/// Records the next key chord pressed after a click, or after Space or
/// Return while the view has keyboard focus. Esc cancels.
final class HotkeyRecorderView: NSView {
    var hotkey: Hotkey = .launcherDefault {
        didSet {
            needsDisplay = true
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }
    var recorderLabel = "Hotkey" {
        didSet { NSAccessibility.post(element: self, notification: .titleChanged) }
    }
    var onChange: ((Hotkey) -> Void)?

    private var recording = false {
        didSet {
            needsDisplay = true
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 26) }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { recorderLabel }
    override func accessibilityValue() -> Any? { recording ? "Recording" : hotkey.displayString }
    override func accessibilityPerformPress() -> Bool {
        startRecording()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        startRecording()
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        let key = Int(event.keyCode)
        guard recording else {
            if key == kVK_Space || key == kVK_Return {
                startRecording()
            } else {
                super.keyDown(with: event)
            }
            return
        }

        if key == kVK_Escape {
            // Cancel without changing the binding.
            window?.makeFirstResponder(nil)
        } else if let recorded = Hotkey(event: event) {
            hotkey = recorded
            onChange?(recorded)
            window?.makeFirstResponder(nil)
        }
    }

    private func startRecording() {
        recording = true
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let label = NSAttributedString(
            string: recording ? "Press shortcut…" : hotkey.displayString,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: recording ? NSColor.controlAccentColor : NSColor.labelColor,
            ]
        )
        let size = label.size()
        label.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}
