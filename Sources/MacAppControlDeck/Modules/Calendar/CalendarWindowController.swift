import AppKit
import SwiftUI

/// 日历窗口控制器不是全局单例：由 CalendarRuntime 持有，随 runtime 一起创建和释放。
@MainActor
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: CalendarStore
    private let preferences: CalendarPreferences
    private var isClosing = false

    /// 窗口关闭后的回调。CalendarModule 根据“常驻内存”决定是否释放整条 runtime。
    var onClose: (() -> Void)?

    init(store: CalendarStore, preferences: CalendarPreferences) {
        self.store = store
        self.preferences = preferences
        super.init()
    }

    var isOpen: Bool {
        window?.isVisible == true
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: CalendarWindowView(
                store: store,
                preferences: preferences,
                onOpenSettings: {
                    MenuBarController.shared.openSettings(tab: .calendar)
                }
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "万年历"
        window.subtitle = "农历、节气、宜忌与节假日"
        window.contentViewController = hosting
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 660, height: 720)
        window.titlebarSeparatorStyle = .none

        if !window.setFrameAutosaveName("CalendarWindowFrame") {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    /// 模块关闭或非常驻窗口关闭时，彻底断开窗口与视图树。
    func shutdown() {
        isClosing = true
        if let window {
            window.delegate = nil
            window.contentViewController = nil
            window.close()
        }
        window = nil
        isClosing = false
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosing else { return }
        isClosing = true
        window?.contentViewController = nil
        window = nil
        let callback = onClose
        isClosing = false
        callback?()
    }
}
