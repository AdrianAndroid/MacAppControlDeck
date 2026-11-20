import AppKit
import Carbon.HIToolbox
import MacShotKit

/// Registers system-wide hot keys through Carbon, so they work while other apps are focused.
final class GlobalHotKeys {
    static let shared = GlobalHotKeys()

    private struct Binding {
        let id: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let action: () -> Void
    }

    private var handler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]

    private static let signature: OSType = 0x4D534B44 // "MSKD"

    func install() {
        guard handler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                               EventParamType(typeEventHotKeyID), nil,
                               MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)

        let bindings: [Binding] = [
            Binding(id: 1, keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.captureArea() }),
            Binding(id: 2, keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.captureFullScreen() }),
            Binding(id: 3, keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.captureWindow() }),
            Binding(id: 4, keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.scrollCapture() }),
            Binding(id: 5, keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.startRecording(format: .mp4, target: .area) }),
            Binding(id: 6, keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.quickOCRArea() }),
            Binding(id: 7, keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MacShotController.shared.reopenLastEditSession() })
        ]

        for binding in bindings {
            actions[binding.id] = binding.action
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
            RegisterEventHotKey(binding.keyCode, binding.modifiers, hotKeyID,
                                GetApplicationEventTarget(), 0, &ref)
            if let ref { hotKeyRefs.append(ref) }
        }
    }

    func uninstall() {
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        actions.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
