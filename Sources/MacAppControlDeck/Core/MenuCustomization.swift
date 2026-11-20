import AppKit
import Combine
import Foundation

/// 用户对一级菜单的定制：模块顺序、模块内命令顺序、隐藏项、置顶到下拉菜单顶部。
/// 只存稳定 ID，不存 NSMenuItem，避免菜单重建后状态丢失。
final class MenuCustomization: ObservableObject {
    static let shared = MenuCustomization()

    @Published private(set) var revision = 0

    private let defaults = UserDefaults.standard

    private func hiddenKey(_ moduleID: String) -> String { "menu.hidden.\(moduleID)" }
    private func orderKey(_ moduleID: String) -> String { "menu.order.\(moduleID)" }
    private let moduleOrderKey = "menu.module.order"
    private let pinnedKey = "menu.pinned"
    private let defaultPinsKey = "menu.defaults.v1"

    private init() {
        applyDefaultPins()
    }

    /// 首次运行给置顶区预置几条高频命令；之后用户自己取消也不会再加回来。
    private func applyDefaultPins() {
        guard !defaults.bool(forKey: defaultPinsKey) else { return }
        var order = pinnedIDs()
        for id in Self.defaultPinnedIDs where !order.contains(id) { order.append(id) }
        defaults.set(order, forKey: pinnedKey)
        defaults.set(true, forKey: defaultPinsKey)
    }

    private static let defaultPinnedIDs: [String] = [
        "capture.全屏截图",
        "capture.区域截图",
        "remote.shortcuts.default.shortcut.missionControl",
        "remote.shortcuts.default.shortcut.copy",
        "sketch.open"
    ]

    // MARK: - 模块顺序

    func moduleOrder() -> [String] {
        defaults.stringArray(forKey: moduleOrderKey) ?? []
    }

    func setModuleOrder(_ ids: [String]) {
        defaults.set(ids, forKey: moduleOrderKey)
        bump()
    }

    func orderedModules(_ modules: [any FeatureModule]) -> [any FeatureModule] {
        let saved = moduleOrder()
        let enabled = modules.filter { ModuleRegistry.shared.isEnabled($0.id) }
        let ordered = saved.compactMap { id in enabled.first { $0.id == id } }
        let rest = enabled.filter { m in !ordered.contains { $0.id == m.id } }
        return ordered + rest
    }

    func moveModule(_ id: String, offset: Int, among modules: [any FeatureModule]) {
        var order = orderedModules(modules).map(\.id)
        guard let index = order.firstIndex(of: id) else { return }
        let target = index + offset
        guard target >= 0, target < order.count else { return }
        order.swapAt(index, target)
        setModuleOrder(order)
    }

    // MARK: - 命令顺序 / 隐藏

    func hiddenCommands(_ moduleID: String) -> Set<String> {
        Set(defaults.stringArray(forKey: hiddenKey(moduleID)) ?? [])
    }

    func isHidden(_ commandID: String, moduleID: String) -> Bool {
        hiddenCommands(moduleID).contains(commandID)
    }

    func setHidden(_ hidden: Bool, commandID: String, moduleID: String) {
        var set = hiddenCommands(moduleID)
        if hidden { set.insert(commandID) } else { set.remove(commandID) }
        defaults.set(Array(set), forKey: hiddenKey(moduleID))
        bump()
    }

    func commandOrder(_ moduleID: String) -> [String] {
        defaults.stringArray(forKey: orderKey(moduleID)) ?? []
    }

    func setCommandOrder(_ ids: [String], moduleID: String) {
        defaults.set(ids, forKey: orderKey(moduleID))
        bump()
    }

    func orderedCommandIDs(_ ids: [String], moduleID: String) -> [String] {
        let saved = commandOrder(moduleID)
        let ordered = saved.filter(ids.contains)
        let rest = ids.filter { id in !ordered.contains(id) }
        return ordered + rest
    }

    func moveCommand(_ id: String, offset: Int, allIDs: [String], moduleID: String) {
        var order = orderedCommandIDs(allIDs, moduleID: moduleID)
        guard let index = order.firstIndex(of: id) else { return }
        let target = index + offset
        guard target >= 0, target < order.count else { return }
        order.swapAt(index, target)
        setCommandOrder(order, moduleID: moduleID)
    }

    // MARK: - 置顶

    /// 置顶项按数组顺序平铺，顺序即用户在一级菜单里看到的顺序。
    func pinnedIDs() -> [String] {
        defaults.stringArray(forKey: pinnedKey) ?? []
    }

    func isPinned(_ commandID: String) -> Bool { pinnedIDs().contains(commandID) }

    func togglePin(_ commandID: String) {
        var order = pinnedIDs()
        if let index = order.firstIndex(of: commandID) {
            order.remove(at: index)
        } else {
            order.append(commandID)
        }
        defaults.set(order, forKey: pinnedKey)
        bump()
    }

    func movePinned(_ commandID: String, offset: Int) {
        var order = pinnedIDs()
        guard let index = order.firstIndex(of: commandID) else { return }
        let target = index + offset
        guard target >= 0, target < order.count else { return }
        order.swapAt(index, target)
        defaults.set(order, forKey: pinnedKey)
        bump()
    }

    private func bump() { revision &+= 1 }

    // MARK: - 设置页读取

    func commands(for module: any FeatureModule) -> [MenuCommandInfo] {
        var infos: [MenuCommandInfo] = []
        for root in module.menuItems() {
            guard let submenu = root.submenu else { continue }
            for item in submenu.items where !item.isSeparatorItem {
                var identifier = item.identifier?.rawValue ?? ""
                if identifier.isEmpty {
                    identifier = "\(module.id).\(Self.slug(item.title))"
                    item.identifier = NSUserInterfaceItemIdentifier(identifier)
                }
                infos.append(MenuCommandInfo(id: identifier,
                                             title: item.title,
                                             image: item.image,
                                             isSubmenu: item.submenu != nil))
            }
        }
        let ids = infos.map(\.id)
        let ordered = orderedCommandIDs(ids, moduleID: module.id)
        return ordered.compactMap { id in infos.first { $0.id == id } }
    }

    static func slug(_ title: String) -> String {
        title.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "（", with: "-")
            .replacingOccurrences(of: "）", with: "")
            .replacingOccurrences(of: "/", with: "-")
    }
}

struct MenuCommandInfo: Identifiable {
    let id: String
    let title: String
    let image: NSImage?
    let isSubmenu: Bool
}
