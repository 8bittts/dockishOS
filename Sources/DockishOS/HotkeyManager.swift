import Carbon.HIToolbox

/// Registers the global hotkeys via Carbon's `RegisterEventHotKey`. Carbon is
/// technically deprecated but `RegisterEventHotKey` remains the only public
/// Apple API for global hotkeys — `NSEvent.addGlobalMonitorForEvents` can't
/// suppress event propagation, which we want for trigger keys like ⌥ Space
/// and ⌥ Tab.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private struct Registration {
        let ref: EventHotKeyRef
        let onFire: @MainActor () -> Void
    }

    private static let signature: OSType = 0x444B5301 // 'DKS\1'

    private var registrations: [HotkeyAction: Registration] = [:]
    private var failures: [HotkeyAction: OSStatus] = [:]
    private var handlerInstalled = false

    private init() {}

    /// Binds `hotkey` to `action`, replacing the action's previous binding.
    func register(_ action: HotkeyAction, hotkey: Hotkey, onFire: @escaping @MainActor () -> Void) {
        if let previous = registrations.removeValue(forKey: action) {
            UnregisterEventHotKey(previous.ref)
        }
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: action.rawValue),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            registrations[action] = Registration(ref: ref, onFire: onFire)
            failures[action] = nil
        } else {
            failures[action] = status
        }
    }

    /// The Carbon error from the last attempt to register `action`, or nil
    /// when its hotkey is live.
    func registrationFailure(for action: HotkeyAction) -> OSStatus? {
        failures[action]
    }

    private func fire(hotkeyID: UInt32) {
        guard let action = HotkeyAction(rawValue: hotkeyID) else { return }
        registrations[action]?.onFire()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr else {
                    Diagnostics.lifecycle.fault("hotkey GetEventParameter failed: \(status)")
                    return noErr
                }
                // Hop off the Carbon dispatch before running app code.
                let id = hotkeyID.id
                Task { @MainActor in HotkeyManager.shared.fire(hotkeyID: id) }
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
            Diagnostics.lifecycle.fault("InstallEventHandler failed: \(status); hotkeys will not fire")
        }
    }
}
