import AppKit
import SwiftUI

/// 状态栏第四个条目：只显示一个日历图标，点击弹纯月历面板。
/// 不持有日历窗口 runtime；面板里的数据都是即时从 CalendarDayBuilder 取的纯值。
///
/// 用自绘无边框 `NSPanel` 而不是 `NSPopover`：popover 的系统箭头与圆角颜色无法跟随
/// 面板背景，看起来像“贴了一块系统白边”；自绘面板圆角、边框与背景一致，并且可以
/// 自己决定点击外部立即关闭。
@MainActor
final class CalendarStatusBarEntry: NSObject, StatusBarEntry {
    let id = "calendar.panel"
    let moduleID = CalendarModule.id
    let groupID = CalendarModule.id
    let order = 3
    let title = "日历"
    let subtitle = "独立状态项 · 点击弹出月历"
    let defaultVisible = true

    var isAvailable: Bool { ModuleRegistry.shared.isEnabled(moduleID) }

    private var panel: CalendarPanel?
    private weak var anchorView: NSView?
    private weak var anchorWindow: NSWindow?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    func makeView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        view.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView(frame: NSRect(x: 2, y: 2, width: 18, height: 18))
        imageView.image = NSImage(systemSymbolName: "calendar",
                                  accessibilityDescription: "日历")
        imageView.symbolConfiguration = .init(pointSize: 15, weight: .regular)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        return view
    }

    func activate(from view: NSView) {
        guard isAvailable else { return }

        // 已打开时再次点击：直接关闭，行为与其他菜单栏面板一致。
        if panel != nil {
            closePanel()
            return
        }
        showPanel(relativeTo: view)
    }

    /// 模块被关闭时由 CalendarModule 调用，确保面板不残留在屏幕上。
    func closePanel() {
        removeMonitors()
        guard let panel else { return }
        self.panel = nil
        panel.orderOut(nil)
    }

    // MARK: - 面板

    private func showPanel(relativeTo view: NSView) {
        guard let window = view.window else { return }
        anchorView = view
        anchorWindow = window

        let size = CalendarPopoverView.panelSize
        let panel = CalendarPanel(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered,
                                  defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        let hosting = NSHostingView(rootView: CalendarPopoverView(
            onOpenFull: { [weak self] in
                self?.closePanel()
                CalendarModule.shared.open()
            },
            onOpenSettings: { [weak self] in
                self?.closePanel()
                MenuBarController.shared.openSettings(tab: .calendar)
            }))
        hosting.wantsLayer = true
        panel.contentView = hosting

        position(panel, below: view, in: window)
        self.panel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    private func position(_ panel: NSPanel, below view: NSView, in window: NSWindow) {
        let rectInWindow = view.convert(view.bounds, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)
        let size = panel.frame.size
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = rectOnScreen.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(rectOnScreen.minY - size.height - 6, visible.maxY)
        panel.setFrame(NSRect(x: x, y: max(y, visible.minY + 8),
                              width: size.width, height: size.height),
                       display: false)
    }

    // MARK: - 关闭

    private func installMonitors() {
        removeMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.panel != nil else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { // esc
                    self.closePanel()
                    return nil
                }
                return event
            }
            if let panel = self.panel, event.window !== panel {
                if event.window === self.anchorWindow, let anchor = self.anchorView {
                    // 点日历图标本身交给 activate() 处理开关；点状态栏其他位置则关闭。
                    let point = anchor.convert(event.locationInWindow, from: nil)
                    if !anchor.bounds.contains(point) {
                        self.closePanel()
                    }
                } else {
                    self.closePanel()
                }
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
    }

    private func removeMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}

/// 无边框、可成为 key 的浮层；圆角与背景由 SwiftUI 内容自己画。
private final class CalendarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
