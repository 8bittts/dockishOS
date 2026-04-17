import AppKit
import Carbon.HIToolbox

/// Registers any number of named global hotkeys via Carbon's
/// `RegisterEventHotKey`. Carbon is technically deprecated but
/// `RegisterEventHotKey` remains the only public Apple API for global
/// hotkeys — `NSEvent.addGlobalMonitorForEvents` can't suppress event
/// propagation, which we want for trigger keys like ⌥ Space and ⌥ Tab.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private struct Registration {
        let id: UInt32
        let ref: EventHotKeyRef
        let callback: () -> Void
    }

    private var registrations: [String: Registration] = [:]
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x444B5301 // 'DKS\1'

    /// Register or replace a named hotkey. Calling with the same `name`
    /// unregisters the previous binding first.
    func register(
        name: String,
        keyCode: UInt32,
        modifiers: UInt32,
        onFire: @escaping () -> Void
    ) {
        unregister(name: name)
        let id = (registrations.values.map(\.id).max() ?? 0) + 1
        let hkID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, hkID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return }
        registrations[name] = Registration(id: id, ref: ref, callback: onFire)
        installHandlerIfNeeded()
    }

    /// Convenience for the launcher (default-name slot).
    func register(
        keyCode: UInt32 = UInt32(kVK_Space),
        modifiers: UInt32 = UInt32(optionKey),
        onFire: @escaping () -> Void
    ) {
        register(name: "launcher", keyCode: keyCode, modifiers: modifiers, onFire: onFire)
    }

    func unregister(name: String) {
        if let r = registrations.removeValue(forKey: name) {
            UnregisterEventHotKey(r.ref)
        }
    }

    func unregister() {
        unregisterAll()
    }

    func unregisterAll() {
        for r in registrations.values { UnregisterEventHotKey(r.ref) }
        registrations.removeAll()
        if let h = handlerRef {
            RemoveEventHandler(h)
            handlerRef = nil
        }
    }

    fileprivate func dispatch(_ id: UInt32) {
        if let reg = registrations.values.first(where: { $0.id == id }) {
            reg.callback()
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                let id = hkID.id
                DispatchQueue.main.async { mgr.dispatch(id) }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
