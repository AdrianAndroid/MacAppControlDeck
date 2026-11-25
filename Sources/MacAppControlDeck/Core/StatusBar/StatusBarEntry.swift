import AppKit

/// 状态栏条目：模块只声明「显示什么、点开什么」，不直接创建 NSStatusItem。
/// 渲染、分组、顺序、开关统一由 `StatusBarRegistry` 负责。
@MainActor
protocol StatusBarEntry: AnyObject {
    /// 唯一键，同时用于偏好持久化，例如 `systemTool.cpu`。
    var id: String { get }
    /// 归属模块 id；模块关闭时该条目在设置里置灰且不出现在状态栏。
    var moduleID: String { get }
    /// 仅用于设置页归类；每个条目各自渲染成独立 NSStatusItem，状态栏先后由 order 决定。
    var groupID: String { get }
    var order: Int { get }
    /// 设置页展示文案。
    var title: String { get }
    var subtitle: String { get }
    /// 首次安装时的默认勾选状态。
    var defaultVisible: Bool { get }
    /// 模块关闭或数据源不可用时返回 false（状态栏移除该格，设置页置灰）。
    var isAvailable: Bool { get }

    /// 创建一个格子视图；同一条目可能被重建多次，实现需每次返回新视图。
    func makeView() -> NSView
    /// 点击格子：默认弹菜单，也可以打开窗口或走深链接。
    func activate(from view: NSView)
}
