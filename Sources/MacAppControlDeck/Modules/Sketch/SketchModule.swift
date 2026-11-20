import AppKit
import SwiftUI

/// UI 草图模块：Mac 本机使用，离线 Excalidraw 画板，不注册 HTTP、不进入手机面板。
@MainActor
final class SketchModule: FeatureModule {
    static let id = "sketch"
    static let shared = SketchModule()

    var id: String { Self.id }
    var title: String { "UI 草图" }
    var summary: String { "鼠标画 UI 意图，复制成图片直接粘贴给 AI；完全离线，不经过手机。" }
    var systemImage: String { "pencil.and.outline" }
    var defaultEnabled: Bool { true }

    private var controller: SketchWindowController { .shared }
    private var store: SketchStore { .shared }

    func start() {}

    func stop() {
        controller.shutdown()
    }

    func menuItems() -> [NSMenuItem] {
        let parent = NSMenuItem(title: "UI 草图", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("sketch.root")

        let submenu = NSMenu(title: "UI 草图")
        parent.submenu = submenu

        submenu.addItem(menuItem(
            "打开画板",
            #selector(openBoard),
            "pencil.and.outline",
            id: "sketch.open",
            key: "d",
            modifiers: [.control, .option]
        ))
        submenu.addItem(menuItem(
            "新建画板",
            #selector(newBoard),
            "doc.badge.plus",
            id: "sketch.new",
            key: "n",
            modifiers: [.command]
        ))
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            "复制当前草图",
            #selector(copyCurrent),
            "doc.on.clipboard",
            id: "sketch.copy",
            key: "c",
            modifiers: [.command, .shift]
        ))
        submenu.addItem(menuItem(
            "保存 PNG 与源文件",
            #selector(saveCurrent),
            "square.and.arrow.down",
            id: "sketch.save",
            key: "s",
            modifiers: [.command]
        ))
        submenu.addItem(.separator())

        let recent = NSMenuItem(title: "最近草图", action: nil, keyEquivalent: "")
        recent.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        recent.identifier = NSUserInterfaceItemIdentifier("sketch.recent")
        let recentMenu = NSMenu(title: "最近草图")
        let items = store.recentSketches()
        if items.isEmpty {
            let empty = NSMenuItem(title: "暂无草图", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
        } else {
            for url in items {
                let child = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(openRecentSketch(_:)),
                    keyEquivalent: ""
                )
                child.target = self
                child.representedObject = url
                child.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                recentMenu.addItem(child)
            }
        }
        recent.submenu = recentMenu
        submenu.addItem(recent)

        submenu.addItem(menuItem(
            "在 Finder 中显示上次保存",
            #selector(revealLastSaved),
            "folder",
            id: "sketch.reveal"
        ))
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            "UI 草图设置…",
            #selector(openSettings),
            "gearshape",
            id: "sketch.settings"
        ))

        return [parent]
    }

    func settingsView() -> AnyView {
        AnyView(SketchSettingsView())
    }

    private func menuItem(
        _ title: String,
        _ selector: Selector,
        _ symbol: String,
        id: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.identifier = NSUserInterfaceItemIdentifier(id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if !key.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        return item
    }

    @objc func openBoard() {
        controller.show()
    }

    @objc func newBoard() {
        controller.newBoard()
    }

    @objc func copyCurrent() {
        controller.copyCurrentSketch()
    }

    @objc func saveCurrent() {
        controller.saveCurrentSketch()
    }

    @objc func openRecentSketch(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        controller.openSketch(at: url)
    }

    @objc func revealLastSaved() {
        store.revealLastSaved()
    }

    @objc func openSettings() {
        MenuBarController.shared.openSettings(tab: .sketch)
    }
}
