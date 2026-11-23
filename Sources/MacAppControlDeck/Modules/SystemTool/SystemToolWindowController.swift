import AppKit
import SwiftUI

@MainActor
final class SystemToolWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let sampler: SystemSampler

    var onClose: (() -> Void)?
    var isOpen: Bool { window?.isVisible == true }

    init(sampler: SystemSampler) {
        self.sampler = sampler
        super.init()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SystemToolRootView(sampler: sampler))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PureMac"
        window.subtitle = "清理、卸载、磁盘与进程"
        window.contentViewController = hosting
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 640, height: 520)
        window.setFrameAutosaveName("SystemToolWindowFrame")
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func shutdown() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }
}
