import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey via Carbon's `RegisterEventHotKey`.
/// Carbon is technically deprecated but `RegisterEventHotKey` remains the
/// only public Apple API for global hotkeys (NSEvent global monitors can't
/// suppress event propagation, which we want for the launcher trigger).
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (() -> Void)?

    /// Register a hotkey. Defaults to ⌥Space (Option+Space) for the launcher.
    func register(
        keyCode: UInt32 = UInt32(kVK_Space),
        modifiers: UInt32 = UInt32(optionKey),
        onFire: @escaping () -> Void
    ) {
        unregister()
        callback = onFire

        let signature: OSType = 0x444B5301 // 'DKS\1'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, ref != nil else { return }
        hotKeyRef = ref

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.callback?() }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
        callback = nil
    }
}
