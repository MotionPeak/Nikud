import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey using the Carbon Hot Key API.
/// This needs no special permission and works while the app is in the background.
final class HotkeyCenter {

    /// Invoked on the main thread whenever the hotkey is pressed.
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handlerInstalled = false

    private static let signature: OSType = 0x4E4B_5544 // "NKUD"

    /// Registers (or, if disabled, clears) the global hotkey.
    func update(keyCode: Int, modifiers: Int, enabled: Bool) {
        unregister()
        guard enabled, keyCode >= 0, modifiers != 0 else { return }
        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: HotkeyCenter.signature, id: 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr {
            hotKeyRef = reference
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { center.onPressed?() }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
