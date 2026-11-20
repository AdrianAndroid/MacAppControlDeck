import AppKit
import SwiftUI

/// 原生状态栏菜单：macshot 同款形态——菜单栏常驻、下拉里是功能按钮、
/// 设置收进独立的首选项窗口。用 NSMenu 而不是 SwiftUI MenuBarExtra，
/// 因为只有原生菜单能给菜单项渲染真实应用图标。
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?
    private let state = DeckState.shared

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = item.button
        if let button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3",
                                   accessibilityDescription: "Mac 应用快捷控制台")
            button.image?.isTemplate = true
            button.toolTip = "Mac 应用快捷控制台"
        }
        menu.delegate = self
        button?.image = nil
        button?.title = "B"
        rebuild()
        button?.title = "A\(menu.items.count)"
        item.menu = menu
        statusItem = item
    }

    // MARK: - 菜单构建

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()

        // 一级菜单 = 「常用」+ 每个已启用模块一个子菜单。
        // 模块内的命令顺序、隐藏、置顶都由 MenuCustomization 决定。
        let customization = MenuCustomization.shared
        let modules = customization.orderedModules(ModuleRegistry.shared.modules)
        var pinned: [NSMenuItem] = []

        for module in modules {
            for raw in module.menuItems() {
                if let submenu = raw.submenu {
                    let rebuilt = customized(submenu, moduleID: module.id, pinned: &pinned)
                    raw.submenu = rebuilt
                    collectPinned(in: rebuilt, into: &pinned)
                }
                menu.addItem(raw)
            }
        }

        // 置顶命令直接平铺在一级菜单顶部，顺序以设置页保存的置顶顺序为准。
        let pinOrder = customization.pinnedIDs()
        pinned.sort { lhs, rhs in
            let left = pinOrder.firstIndex(of: lhs.identifier?.rawValue ?? "") ?? Int.max
            let right = pinOrder.firstIndex(of: rhs.identifier?.rawValue ?? "") ?? Int.max
            return left < right
        }
        if !pinned.isEmpty {
            for (index, item) in pinned.enumerated() {
                menu.insertItem(clone(item), at: index)
            }
            menu.insertItem(.separator(), at: pinned.count)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("设置…", #selector(openSettingsFromMenu),
                                image: "gearshape", keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出 Mac 应用快捷控制台", #selector(quit), image: "power",
                                keyEquivalent: "q"))
    }

    /// 原地重排模块子菜单：按保存顺序排列、去掉隐藏项，并收集置顶命令。
    /// 不能把旧菜单里的 item 直接加进一个新菜单，AppKit 会抛异常中断装配。
    private func customized(_ submenu: NSMenu, moduleID: String, pinned: inout [NSMenuItem]) -> NSMenu {
        let customization = MenuCustomization.shared
        var commands: [(id: String, item: NSMenuItem)] = []
        var seen = Set<String>()
        for item in submenu.items {
            guard !item.isSeparatorItem else { continue }
            var identifier = item.identifier?.rawValue ?? ""
            if identifier.isEmpty {
                identifier = "\(moduleID).\(MenuCustomization.slug(item.title))"
            }
            var unique = identifier
            var suffix = 2
            while seen.contains(unique) {
                unique = "\(identifier)#\(suffix)"
                suffix += 1
            }
            seen.insert(unique)
            item.identifier = NSUserInterfaceItemIdentifier(unique)
            commands.append((unique, item))
        }
        guard !commands.isEmpty else { return submenu }

        let ids = commands.map(\.id)
        let ordered = customization.orderedCommandIDs(ids, moduleID: moduleID)
        let hidden = customization.hiddenCommands(moduleID)
        var byID: [String: NSMenuItem] = [:]
        for command in commands { byID[command.id] = command.item }

        submenu.removeAllItems()
        for id in ordered {
            guard let item = byID[id] else { continue }
            if customization.isPinned(id) { pinned.append(item) }
            if hidden.contains(id) { continue }
            submenu.addItem(item)
        }
        if submenu.items.isEmpty {
            let empty = NSMenuItem(title: "模块内命令已全部隐藏", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        return submenu
    }

    /// 「应用」「快捷操作」等二级子菜单里的命令也要能置顶，递归把命中项收集出来。
    private func collectPinned(in menu: NSMenu, into pinned: inout [NSMenuItem]) {
        let customization = MenuCustomization.shared
        var known = Set(pinned.compactMap { $0.identifier?.rawValue })
        for item in menu.items {
            if let id = item.identifier?.rawValue,
               customization.isPinned(id),
               !known.contains(id) {
                pinned.append(item)
                known.insert(id)
            }
            if let submenu = item.submenu {
                collectPinned(in: submenu, into: &pinned)
            }
        }
    }

    private func clone(_ item: NSMenuItem) -> NSMenuItem {
        let copy = NSMenuItem(title: item.title, action: item.action, keyEquivalent: item.keyEquivalent)
        copy.target = item.target
        copy.representedObject = item.representedObject
        copy.image = item.image
        copy.state = item.state
        copy.isEnabled = item.isEnabled
        copy.identifier = item.identifier
        if let sub = item.submenu {
            let menu = NSMenu(title: sub.title)
            sub.items.forEach { menu.addItem(clone($0)) }
            copy.submenu = menu
        }
        return copy
    }


    private func actionItem(_ title: String,
                            _ selector: Selector,
                            image: String? = nil,
                            keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        item.target = self
        if let image {
            item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        }
        return item
    }

    // MARK: - 动作

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 首选项窗口

    func openSettings(tab: SettingsTab? = nil) {
        if let tab {
            state.requestedSettingsTab = tab
        }
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
