import AppKit
import Combine
import Foundation

/// 模块注册表：只做三件事——保存开关、启动/停止模块、把模块菜单拼给菜单栏。
/// 不持有任何模块的业务对象。
final class ModuleRegistry: ObservableObject {
    static let shared = ModuleRegistry()

    @Published private(set) var modules: [any FeatureModule] = []
    @Published private(set) var enabledIDs: Set<String> = []

    private let defaults = UserDefaults.standard

    private func storageKey(_ id: String) -> String { "module.enabled.\(id)" }

    func register(_ module: any FeatureModule) {
        guard !modules.contains(where: { $0.id == module.id }) else { return }
        modules.append(module)
        if isEnabled(module.id) {
            enabledIDs.insert(module.id)
            module.start()
        }
    }

    func module(id: String) -> (any FeatureModule)? {
        modules.first { $0.id == id }
    }

    func isEnabled(_ id: String) -> Bool {
        guard let module = module(id: id) else { return false }
        if let stored = defaults.object(forKey: storageKey(id)) as? Bool {
            return stored
        }
        return module.defaultEnabled
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let module = module(id: id) else { return }
        defaults.set(enabled, forKey: storageKey(id))
        if enabled {
            if !enabledIDs.contains(id) {
                enabledIDs.insert(id)
                module.start()
            }
        } else {
            if enabledIDs.contains(id) {
                enabledIDs.remove(id)
                module.stop()
            }
        }
    }

    /// 菜单栏按注册顺序取已启用模块的菜单项。
    func menuItems() -> [NSMenuItem] {
        modules
            .filter { isEnabled($0.id) }
            .flatMap { $0.menuItems() }
    }
}
