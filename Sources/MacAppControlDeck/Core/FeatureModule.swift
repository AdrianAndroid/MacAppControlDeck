import AppKit
import SwiftUI

/// 一个功能模块的最小契约。
/// Core 只负责注册、开关、菜单拼接和设置容器；模块自己管服务、数据、权限和生命周期。
protocol FeatureModule: AnyObject {
    var id: String { get }
    var title: String { get }
    var summary: String { get }
    var systemImage: String { get }
    var defaultEnabled: Bool { get }

    func start()
    func stop()
    func menuItems() -> [NSMenuItem]
    func settingsView() -> AnyView
}

extension FeatureModule {
    func menuItems() -> [NSMenuItem] { [] }
}
