import AppKit

/// 右键菜单。闭包由 runtime 注入，避免面板直接依赖设置窗口。
@MainActor
final class PetMenuHost: NSObject {
    var actions: [String: () -> Void] = [:]

    func menu(settings: PetSettings, state: PetStateMachine) -> NSMenu {
        let menu = NSMenu(title: "桌面宠物")
        menu.autoenablesItems = false

        menu.addItem(item("打开桌宠设置…", symbol: "gearshape", id: "pet.settings",
                          key: "comma", modifiers: [.command]))
        menu.addItem(.separator())

        let paused = item(settings.paused ? "继续互动" : "暂停互动",
                          symbol: settings.paused ? "play.fill" : "pause.fill",
                          id: "pet.pause")
        paused.state = settings.paused ? .on : .off
        menu.addItem(paused)

        let locked = item(settings.locked ? "解锁位置" : "锁定位置",
                          symbol: settings.locked ? "lock.open" : "lock",
                          id: "pet.lock")
        locked.state = settings.locked ? .on : .off
        menu.addItem(locked)

        let through = item(settings.clickThrough ? "关闭点击穿透" : "开启点击穿透",
                           symbol: "cursorarrow.rays",
                           id: "pet.clickThrough")
        through.state = settings.clickThrough ? .on : .off
        menu.addItem(through)

        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "尺寸", action: nil, keyEquivalent: "")
        sizeItem.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)
        let sizeMenu = NSMenu(title: "尺寸")
        for size in PetSize.allCases {
            let child = item("\(size.label)号", symbol: size == settings.size ? "checkmark" : "circle",
                             id: "pet.size.\(size.rawValue)")
            child.state = size == settings.size ? .on : .off
            child.representedObject = "pet.size.\(size.rawValue)"
            sizeMenu.addItem(child)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        menu.addItem(item("回到默认位置", symbol: "arrow.uturn.backward", id: "pet.resetPosition"))
        menu.addItem(item("隐藏桌宠", symbol: "eye.slash", id: "pet.hide"))
        return menu
    }

    private func item(_ title: String,
                      symbol: String,
                      id: String,
                      key: String = "",
                      modifiers: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: #selector(fire(_:)), keyEquivalent: key)
        menuItem.target = self
        menuItem.identifier = NSUserInterfaceItemIdentifier(id)
        menuItem.representedObject = id
        menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if !key.isEmpty {
            menuItem.keyEquivalentModifierMask = modifiers
        }
        return menuItem
    }

    @objc private func fire(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        actions[id]?()
    }
}
