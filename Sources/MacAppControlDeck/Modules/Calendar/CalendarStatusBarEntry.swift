import AppKit
import SwiftUI

/// 状态栏第四个条目：只显示一个日历图标，点击弹纯月历 NSPopover。
/// 不持有日历窗口 runtime；面板里的数据都是即时从 CalendarDayBuilder 取的纯值。
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

    private var popover: NSPopover?

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

        // 已打开时再次点击：直接关闭，行为与其他菜单栏 popover 一致。
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let panel = NSPopover()
        panel.behavior = .transient
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentSize = NSSize(width: 336, height: 382)
        let hosting = NSHostingController(rootView: CalendarPopoverView(
            onOpenFull: { [weak self] in
                self?.popover?.performClose(nil)
                CalendarModule.shared.open()
            },
            onOpenSettings: { [weak self] in
                self?.popover?.performClose(nil)
                MenuBarController.shared.openSettings(tab: .calendar)
            }).environment(\.colorScheme, .dark))
        panel.contentViewController = hosting
        panel.delegate = self
        self.popover = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    /// 模块被关闭时由 CalendarModule 调用，确保面板不残留在屏幕上。
    func closePanel() {
        popover?.performClose(nil)
        popover = nil
    }
}

extension CalendarStatusBarEntry: NSPopoverDelegate {
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.popover = nil }
    }
}
