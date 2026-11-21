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

    /// 是否支持“常驻内存”设置。默认不支持，核心模块或轻量代理不需要额外开关。
    var supportsResidency: Bool { get }
    var isResident: Bool { get }
    func setResident(_ resident: Bool)
}

extension FeatureModule {
    func menuItems() -> [NSMenuItem] { [] }
    var supportsResidency: Bool { false }
    var isResident: Bool { true }
    func setResident(_ resident: Bool) {}
}
