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
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3",
                                   accessibilityDescription: "Mac 应用快捷控制台")
            button.image?.isTemplate = true
            button.toolTip = "Mac 应用快捷控制台"
        }
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    // MARK: - 菜单构建

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        let remoteEnabled = ModuleRegistry.shared.isEnabled(RemoteControlModule.id)

        if remoteEnabled {
            // 面板入口与状态
            let addressItem = NSMenuItem(title: "面板：\(state.panelAddressText)",
                                         action: nil, keyEquivalent: "")
            addressItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
            addressItem.isEnabled = false
            menu.addItem(addressItem)

            menu.addItem(actionItem("在浏览器打开面板", #selector(openPanel), image: "safari"))
            menu.addItem(actionItem("复制面板地址", #selector(copyPanel), image: "doc.on.doc"))
            menu.addItem(.separator())

            // 功能按钮：与手机面板共用同一份配置
            if state.buttons.isEmpty {
                menu.addItem(actionItem("还没有按钮，去设置里添加…", #selector(openSettingsFromMenu), image: "plus"))
            } else {
                if !state.appButtons.isEmpty {
                    menu.addItem(submenuItem("应用", symbol: "square.grid.2x2", buttons: state.appButtons))
                }
                if !state.quickButtons.isEmpty {
                    menu.addItem(submenuItem("快捷操作", symbol: "keyboard", buttons: state.quickButtons))
                }
            }

            menu.addItem(.separator())
            menu.addItem(actionItem("配对手机…", #selector(pairPhone), image: "iphone"))
            menu.addItem(actionItem(state.serverStatus.running ? "重启服务" : "启动服务",
                                    #selector(restartServer), image: "arrow.clockwise"))
        } else {
            let off = NSMenuItem(title: "电脑遥控已关闭", action: nil, keyEquivalent: "")
            off.image = NSImage(systemSymbolName: "iphone.slash", accessibilityDescription: nil)
            off.isEnabled = false
            menu.addItem(off)
            menu.addItem(actionItem("在设置中开启…", #selector(openSettingsFromMenu), image: "gearshape"))
        }

        // 已启用的功能模块各自贡献菜单项；模块之间不共享菜单状态。
        let moduleItems = ModuleRegistry.shared.menuItems()
        if !moduleItems.isEmpty {
            menu.addItem(.separator())
            moduleItems.forEach { menu.addItem($0) }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("设置…", #selector(openSettingsFromMenu),
                                image: "gearshape", keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出 Mac 应用快捷控制台", #selector(quit), image: "power",
                                keyEquivalent: "q"))
    }

    private func submenuItem(_ title: String, symbol: String, buttons: [ButtonConfig]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let submenu = NSMenu(title: title)
        for button in buttons {
            let item = NSMenuItem(title: menuTitle(for: button),
                                  action: #selector(performButton(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = button
            item.image = state.icon(for: button)
            if !state.isInstalled(button) { item.isEnabled = false }
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func menuTitle(for button: ButtonConfig) -> String {
        switch button.kind {
        case .app:
            return state.isInstalled(button) ? button.name : "\(button.name)（缺失）"
        case .shortcut:
            return "\(button.name)   \(button.displaySymbol ?? "")"
        case .command:
            return "\(button.name)"
        }
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

    @objc private func performButton(_ sender: NSMenuItem) {
        guard let button = sender.representedObject as? ButtonConfig else { return }
        state.perform(button)
    }

    @objc private func openPanel() {
        state.openPanelInBrowser()
    }

    @objc private func copyPanel() {
        state.copyPanelURL()
    }

    @objc private func pairPhone() {
        state.generatePairingCode()
        openSettings(tab: .general)
    }

    @objc private func restartServer() {
        state.restart()
    }

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
