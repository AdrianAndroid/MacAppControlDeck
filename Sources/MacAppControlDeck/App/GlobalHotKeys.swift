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
    private var pendingBindings: [(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: () -> Void)] = []
    private var retryTimer: Timer?

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
                    action: { MainActor.assumeIsolated { MacShotController.shared.captureArea() } }),
            Binding(id: 2, keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.captureFullScreen() } }),
            Binding(id: 3, keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.captureWindow() } }),
            Binding(id: 4, keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.scrollCapture() } }),
            Binding(id: 5, keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.startRecording(format: .mp4, target: .area) } }),
            Binding(id: 6, keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.quickOCRArea() } }),
            Binding(id: 7, keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey | shiftKey),
                    action: { MainActor.assumeIsolated { MacShotController.shared.reopenLastEditSession() } })
        ]

        for binding in bindings {
            actions[binding.id] = binding.action
        }
        registerPending(bindings.map {
            (id: $0.id, keyCode: $0.keyCode, modifiers: $0.modifiers, action: $0.action)
        })
    }

    /// 热键可能被其他程序（例如已运行的 macshot）占用而注册失败；
    /// 记录失败的绑定并在 2 秒后重试，避免永久失去快捷键。
    private func registerPending(_ bindings: [(id: UInt32, keyCode: UInt32, modifiers: UInt32,
                                             action: () -> Void)]) {
        pendingBindings = []
        for binding in bindings {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, hotKeyID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
            } else {
                pendingBindings.append(binding)
            }
        }
        guard !pendingBindings.isEmpty else {
            retryTimer?.invalidate()
            retryTimer = nil
            return
        }
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let retry = self.pendingBindings
            self.registerPending(retry)
        }
    }

    func uninstall() {
        retryTimer?.invalidate()
        retryTimer = nil
        pendingBindings = []
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        actions.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
