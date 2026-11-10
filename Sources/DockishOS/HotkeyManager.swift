import Carbon.HIToolbox

/// Registers the app switcher's global hotkey via Carbon's
/// `RegisterEventHotKey`. Carbon is technically deprecated but
/// `RegisterEventHotKey` remains the only public Apple API for global
/// hotkeys — `NSEvent.addGlobalMonitorForEvents` can't suppress event
/// propagation, which we want for a trigger key like ⌥ Tab.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let hotkeyID = EventHotKeyID(signature: 0x444B5301 /* 'DKS\1' */, id: 1)

    private var hotkeyRef: EventHotKeyRef?
    private var onFire: (@MainActor () -> Void)?
    private var handlerInstalled = false

    /// The Carbon error from the last `register` call, or nil when the
    /// hotkey is live.
    private(set) var registrationFailure: OSStatus?

    private init() {}

    /// Binds `hotkey`, replacing the previous binding.
    func register(_ hotkey: Hotkey, onFire: @escaping @MainActor () -> Void) {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        installHandlerIfNeeded()
        self.onFire = onFire

        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            Self.hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        registrationFailure = status == noErr ? nil : status
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                // Hop off the Carbon dispatch before running app code.
                Task { @MainActor in HotkeyManager.shared.onFire?() }
                return noErr
            },
            1,
            &spec,
            nil,
            nil
        )
        if status == noErr {
            handlerInstalled = true
        } else {
            Diagnostics.lifecycle.fault("InstallEventHandler failed: \(status); the app switcher shortcut will not fire")
        }
    }
}
