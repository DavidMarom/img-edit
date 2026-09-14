import Carbon.HIToolbox
import AppKit

/// Registers a fixed global hotkey (Cmd+Shift+E) via the Carbon Hot Key API.
/// This mechanism does not require Accessibility/Input Monitoring permission —
/// that's only needed for simulating input or reading other apps' windows,
/// neither of which this app does. See docs/adr/0002-carbon-hotkey-no-permission.md.
final class HotKeyManager {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = 0x494D4745 // "IMGE"
    private static let hotKeyID: UInt32 = 1

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            var receivedID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &receivedID)
            if receivedID.id == HotKeyManager.hotKeyID {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onTrigger?() }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)

        let id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let keyCode = UInt32(kVK_ANSI_E)
        let modifiers = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
