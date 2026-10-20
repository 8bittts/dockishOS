import AppKit

let app = NSApplication.shared
// Top-level code runs on the main thread.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
