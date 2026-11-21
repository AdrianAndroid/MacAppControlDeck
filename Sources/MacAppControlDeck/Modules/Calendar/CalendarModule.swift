import AppKit
import SwiftUI

/// 打开窗口时创建、关闭窗口时释放的整条日历运行时。
@MainActor
final class CalendarRuntime {
    let store: CalendarStore
    let controller: CalendarWindowController

    init(preferences: CalendarPreferences = .shared) {
        let store = CalendarStore(preferences: preferences)
        self.store = store
        controller = CalendarWindowController(store: store, preferences: preferences)
    }
}

/// 菜单栏长期持有的轻量代理：只保存可选 runtime，不保存窗口、视图或日历数据。
@MainActor
final class CalendarModule: FeatureModule {
    static let id = "calendar"
    static let shared = CalendarModule()

    private var runtime: CalendarRuntime?

    var id: String { Self.id }
    var title: String { "万年历" }
    var summary: String { "农历、节气、宜忌与法定节假日；默认打开才加载，关闭窗口即释放。" }
    var systemImage: String { "calendar" }
    var defaultEnabled: Bool { true }

    var supportsResidency: Bool { true }
    var isResident: Bool { CalendarPreferences.shared.resident }
    var isRuntimeLoaded: Bool { runtime != nil }

    func start() {
        if isResident {
            _ = ensureRuntime()
        }
    }

    func stop() {
        releaseRuntime()
    }

    func setResident(_ resident: Bool) {
        CalendarPreferences.shared.resident = resident
        if resident {
            _ = ensureRuntime()
        } else if let runtime, !runtime.controller.isOpen {
            releaseRuntime()
        }
    }

    func open() {
        let runtime = ensureRuntime()
        runtime.controller.show()
    }

    func menuItems() -> [NSMenuItem] {
        let parent = NSMenuItem(title: "万年历", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("calendar.root")

        let submenu = NSMenu(title: "万年历")
        parent.submenu = submenu

        let summary = CalendarMenuSummary.todayText()
        let today = NSMenuItem(title: summary.solar, action: nil, keyEquivalent: "")
        today.isEnabled = false
        submenu.addItem(today)

        let almanac = NSMenuItem(title: summary.almanac, action: nil, keyEquivalent: "")
        almanac.isEnabled = false
        submenu.addItem(almanac)

        let countdown = NSMenuItem(title: CalendarStore.countdownText(), action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        submenu.addItem(countdown)

        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            "打开万年历…",
            #selector(openFromMenu),
            "calendar.badge.clock",
            id: "calendar.open"
        ))
        submenu.addItem(menuItem(
            "万年历设置…",
            #selector(openSettings),
            "gearshape",
            id: "calendar.settings"
        ))

        return [parent]
    }

    func settingsView() -> AnyView {
        AnyView(CalendarSettingsView())
    }

    private func menuItem(_ title: String, _ selector: Selector, _ symbol: String, id: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.identifier = NSUserInterfaceItemIdentifier(id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private func ensureRuntime() -> CalendarRuntime {
        if let runtime {
            return runtime
        }
        let runtime = CalendarRuntime()
        runtime.controller.onClose = { [weak self] in
            guard let self else { return }
            guard !self.isResident else { return }
            // 等窗口关闭回调彻底退出后再释放 controller 自身。
            DispatchQueue.main.async {
                self.releaseRuntime()
            }
        }
        self.runtime = runtime
        return runtime
    }

    private func releaseRuntime() {
        runtime?.controller.shutdown()
        runtime = nil
    }

    @objc private func openFromMenu() {
        open()
    }

    @objc private func openSettings() {
        MenuBarController.shared.openSettings(tab: .calendar)
    }
}
