import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Button that shows a shortcut and records a replacement. Press it, then
/// press the new chord. Esc, a second press, leaving the pane, or the window
/// losing focus cancels without changing the shortcut.
struct HotkeyRecorder: View {
    let title: String
    @Binding var hotkey: Hotkey
    /// The key-down monitor that exists while recording.
    @State private var monitor: Any?

    private var isRecording: Bool { monitor != nil }

    var body: some View {
        Button(isRecording ? "Press Shortcut…" : hotkey.displayString) {
            isRecording ? stopRecording() : startRecording()
        }
        .accessibilityLabel(title)
        .accessibilityValue(isRecording ? "Recording" : hotkey.displayString)
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            stopRecording()
        }
    }

    private func startRecording() {
        // Every key press belongs to the recorder until it stops.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopRecording()
            } else if let recorded = Hotkey(event: event) {
                hotkey = recorded
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
