import AppKit
import SwiftUI

/// 菜单栏长期持有的轻量代理。隐藏桌宠后释放整条 runtime。
@MainActor
final class PetModule: FeatureModule {
    static let id = "pet"
    static let shared = PetModule()
    static let runtimeDidChange = Notification.Name("PetModule.runtimeDidChange")

    private var runtime: PetRuntime?

    var id: String { Self.id }
    var title: String { "桌面宠物" }
    var summary: String { "键鼠联动的桌面猫狗；三档尺寸、五套皮肤、透明置顶，隐藏即释放。" }
    var systemImage: String { "cat.fill" }
    var defaultEnabled: Bool { true }

    var isRuntimeLoaded: Bool { runtime != nil }

    func start() {
        let settings = PetSettings.shared
        if settings.randomSkinOnLaunch, let random = PetSkinCatalog.all.randomElement() {
            settings.chooseSkin(random.id)
        }
        if settings.visible || !settings.firstRunDone {
            let runtime = ensureRuntime()
            runtime.start()
            if !settings.firstRunDone {
                settings.firstRunDone = true
                runtime.show()
            } else if settings.visible {
                runtime.show()
            }
        }
    }

    func stop() {
        releaseRuntime()
    }

    func open() {
        let runtime = ensureRuntime()
        runtime.start()
        runtime.show()
    }

    func toggle() {
        if let runtime, runtime.isOpen {
            runtime.hide()
        } else {
            open()
        }
    }

    func hide() {
        runtime?.hide()
    }

    func menuItems() -> [NSMenuItem] {
        let parent = NSMenuItem(title: "桌面宠物", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("pet.root")
        let submenu = NSMenu(title: "桌面宠物")
        parent.submenu = submenu

        submenu.addItem(item("打开桌宠", #selector(openFromMenu), "cat.fill", id: "pet.open",
                             key: "p", modifiers: [.control, .option]))
        if let runtime, runtime.isOpen {
            submenu.addItem(item("隐藏桌宠", #selector(hideFromMenu), "eye.slash", id: "pet.hide"))
        }
        submenu.addItem(.separator())

        let paused = item(PetSettings.shared.paused ? "继续互动" : "暂停互动",
                          #selector(togglePause), "pause.circle", id: "pet.pause")
        paused.state = PetSettings.shared.paused ? .on : .off
        submenu.addItem(paused)

        let through = item(PetSettings.shared.clickThrough ? "关闭点击穿透" : "开启点击穿透",
                           #selector(toggleClickThrough), "cursorarrow.rays", id: "pet.clickThrough")
        through.state = PetSettings.shared.clickThrough ? .on : .off
        submenu.addItem(through)

        let sizeItem = NSMenuItem(title: "尺寸", action: nil, keyEquivalent: "")
        sizeItem.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)
        let sizeMenu = NSMenu(title: "尺寸")
        for size in PetSize.allCases {
            let child = NSMenuItem(title: "\(size.label)号", action: #selector(changeSize(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = size.rawValue
            child.state = PetSettings.shared.size == size ? .on : .off
            sizeMenu.addItem(child)
        }
        sizeItem.submenu = sizeMenu
        submenu.addItem(sizeItem)

        let skinItem = NSMenuItem(title: "换肤", action: nil, keyEquivalent: "")
        skinItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        let skinMenu = NSMenu(title: "换肤")
        for skin in PetSkinCatalog.all {
            let child = NSMenuItem(title: skin.name, action: #selector(changeSkin(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = skin.id
            child.state = PetSettings.shared.skinID == skin.id ? .on : .off
            skinMenu.addItem(child)
        }
        skinItem.submenu = skinMenu
        submenu.addItem(skinItem)

        submenu.addItem(.separator())
        submenu.addItem(item("重置位置", #selector(resetPosition), "arrow.uturn.backward", id: "pet.resetPosition"))
        submenu.addItem(item("桌面宠物设置…", #selector(openSettings), "gearshape", id: "pet.settings"))
        return [parent]
    }

    func settingsView() -> AnyView {
        AnyView(PetSettingsView())
    }

    private func item(_ title: String,
                      _ selector: Selector,
                      _ symbol: String,
                      id: String,
                      key: String = "",
                      modifiers: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.identifier = NSUserInterfaceItemIdentifier(id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if !key.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        return item
    }

    private func ensureRuntime() -> PetRuntime {
        if let runtime { return runtime }
        let runtime = PetRuntime(settings: .shared)
        runtime.onHidden = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let runtime = self.runtime, !runtime.isOpen else { return }
                self.releaseRuntime()
            }
        }
        self.runtime = runtime
        NotificationCenter.default.post(name: Self.runtimeDidChange, object: nil)
        return runtime
    }

    private func releaseRuntime() {
        runtime?.shutdown()
        runtime = nil
        NotificationCenter.default.post(name: Self.runtimeDidChange, object: nil)
    }

    @objc private func openFromMenu() {
        open()
    }

    @objc private func hideFromMenu() {
        hide()
    }

    @objc private func togglePause() {
        PetSettings.shared.paused.toggle()
    }

    @objc private func toggleClickThrough() {
        PetSettings.shared.clickThrough.toggle()
    }

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = PetSize(rawValue: raw) else { return }
        if let runtime {
            runtime.setSize(size)
        } else {
            PetSettings.shared.size = size
        }
    }

    @objc private func changeSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        PetSettings.shared.chooseSkin(id)
        if let runtime {
            runtime.state.skin = PetSettings.shared.skin
            runtime.state.keyboardTheme = PetSettings.shared.keyboardTheme
        }
    }

    @objc func resetPosition() {
        PetSettings.shared.resetPosition()
        if let runtime, runtime.isOpen {
            runtime.resetPosition()
        }
    }

    @objc private func openSettings() {
        MenuBarController.shared.openSettings(tab: .pet)
    }
}
