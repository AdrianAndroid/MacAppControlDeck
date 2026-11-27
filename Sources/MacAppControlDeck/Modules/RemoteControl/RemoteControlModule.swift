import AppKit
import SwiftUI

/// 电脑遥控模块：手机通过局域网面板控制 Mac 应用、快捷键和命令。
/// 它的服务、配对、设备、按钮配置都在这一模块内，不与截图模块共享状态。
final class RemoteControlModule: FeatureModule {
    static let id = "remote"

    var id: String { Self.id }
    var title: String { "电脑控制" }
    var summary: String { "打开局域网面板、运行应用/快捷键按钮，以及配对手机。" }
    var systemImage: String { "iphone.radiowaves.left.and.right" }
    var defaultEnabled: Bool { true }

    func start() {
        DeckState.shared.start()
    }

    func stop() {
        DeckState.shared.stop()
    }

    func menuItems() -> [NSMenuItem] {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("remote.root")

        let submenu = NSMenu(title: title)
        let state = DeckState.shared
        // 菜单打开时强制重算一次，NWPathMonitor 偶发延迟也不会显示旧 IP。
        state.refreshAddresses()

        let address = NSMenuItem(title: "面板：\(state.panelAddressText)", action: nil, keyEquivalent: "")
        address.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
        address.identifier = NSUserInterfaceItemIdentifier("remote.address")
        address.isEnabled = false
        submenu.addItem(address)

        submenu.addItem(actionItem("在浏览器打开面板", #selector(openPanel),
                                   image: "safari", id: "remote.openPanel"))
        submenu.addItem(actionItem("复制面板地址", #selector(copyPanel),
                                   image: "doc.on.doc", id: "remote.copyPanel"))
        submenu.addItem(actionItem("刷新网络地址（切换 Wi-Fi 后）", #selector(refreshAddress),
                                   image: "arrow.clockwise", id: "remote.refreshAddress"))
        submenu.addItem(actionItem("显示面板二维码…", #selector(showPanelQR),
                                   image: "qrcode", id: "remote.panelQR"))
        submenu.addItem(.separator())

        let screen = NSMenuItem(title: "副屏：\(state.screenAddressText)", action: nil, keyEquivalent: "")
        screen.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        screen.identifier = NSUserInterfaceItemIdentifier("remote.screenAddress")
        screen.isEnabled = false
        submenu.addItem(screen)

        submenu.addItem(actionItem("在浏览器打开副屏", #selector(openScreen),
                                   image: "safari", id: "remote.openScreen"))
        submenu.addItem(actionItem("复制副屏地址", #selector(copyScreen),
                                   image: "doc.on.doc", id: "remote.copyScreen"))
        submenu.addItem(actionItem("显示副屏二维码…", #selector(showScreenQR),
                                   image: "qrcode", id: "remote.screenQR"))
        submenu.addItem(actionItem("副屏设置…", #selector(openScreenSettings),
                                   image: "gearshape", id: "remote.screenSettings"))
        submenu.addItem(.separator())

        if state.buttons.isEmpty {
            submenu.addItem(actionItem("还没有按钮，去设置里添加…", #selector(openButtonSettings),
                                       image: "plus", id: "remote.emptyButtons"))
        } else {
            if !state.appButtons.isEmpty {
                submenu.addItem(buttonSubmenu("应用", symbol: "square.grid.2x2",
                                              buttons: state.appButtons, id: "remote.apps"))
            }
            if !state.quickButtons.isEmpty {
                submenu.addItem(buttonSubmenu("快捷操作", symbol: "keyboard",
                                              buttons: state.quickButtons, id: "remote.shortcuts"))
            }
        }

        submenu.addItem(.separator())
        submenu.addItem(actionItem("配对手机…", #selector(pairPhone), image: "iphone",
                                   id: "remote.pair"))
        submenu.addItem(actionItem(state.serverStatus.running ? "重启服务" : "启动服务",
                                   #selector(restartServer), image: "arrow.clockwise",
                                   id: "remote.restart"))
        parent.submenu = submenu
        return [parent]
    }

    func settingsView() -> AnyView {
        AnyView(RemoteControlModuleSettingsView())
    }

    private func actionItem(_ title: String, _ selector: Selector, image: String, id: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        item.identifier = NSUserInterfaceItemIdentifier(id)
        return item
    }

    private func buttonSubmenu(_ title: String, symbol: String, buttons: [ButtonConfig], id: String) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier(id)
        let submenu = NSMenu(title: title)
        let state = DeckState.shared
        for button in buttons {
            let item = NSMenuItem(title: state.menuTitle(for: button),
                                  action: #selector(performButton(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = button
            item.image = state.icon(for: button)
            item.identifier = NSUserInterfaceItemIdentifier("\(id).\(button.id)")
            if !state.isInstalled(button) { item.isEnabled = false }
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    @objc private func performButton(_ sender: NSMenuItem) {
        guard let button = sender.representedObject as? ButtonConfig else { return }
        DeckState.shared.perform(button)
    }

    @objc private func openPanel() { DeckState.shared.openPanelInBrowser() }
    @objc private func copyPanel() { DeckState.shared.copyPanelURL() }
    @objc private func refreshAddress() { DeckState.shared.refreshAddresses() }
    @objc private func showPanelQR() {
        DeckState.shared.refreshAddresses()
        MenuBarController.shared.openSettings(tab: .remoteService)
    }
    @objc private func openScreen() { DeckState.shared.openScreenInBrowser() }
    @objc private func copyScreen() { DeckState.shared.copyScreenURL() }
    @objc private func showScreenQR() {
        DeckState.shared.refreshAddresses()
        MenuBarController.shared.openSettings(tab: .screen)
    }
    @objc private func openScreenSettings() {
        MenuBarController.shared.openSettings(tab: .screen)
    }
    @objc private func openButtonSettings() {
        MenuBarController.shared.openSettings(tab: .buttons)
    }
    @objc private func pairPhone() {
        DeckState.shared.generatePairingCode()
        MenuBarController.shared.openSettings(tab: .remoteService)
    }
    @objc private func restartServer() { DeckState.shared.restart() }
}

private struct RemoteControlModuleSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手机配对、按钮配置和设备管理分别在「按钮」与「设备」页。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
