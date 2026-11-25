import AppKit
import SwiftUI
import Combine

/// 系统工具模块（用户可见名 PureMac）：单一 FeatureModule，承载清理/卸载/大文件/
/// 重复文件/进程/菜单栏监控。内部把「常驻采样」与「按需扫描」拆成两条独立路径。
@MainActor
final class SystemToolModule: FeatureModule {
    static let id = "systemTool"
    static let shared = SystemToolModule()

    var id: String { Self.id }
    var title: String { "PureMac" }
    var summary: String { "垃圾清理、应用卸载、大文件与重复文件、进程退出、菜单栏 CPU/MEM/网速监控。" }
    var systemImage: String { "trash.fill" }
    var defaultEnabled: Bool { true }
    var supportsResidency: Bool { false }

    let sampler = SystemSampler()
    private var windowController: SystemToolWindowController?
    /// 状态栏监控条目（注册进公共层后长期复用）。
    private var statusEntries: [StatusBarEntry] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - FeatureModule lifecycle

    func start() {
        sampler.start()
        registerStatusEntriesIfNeeded()
    }

    func stop() {
        sampler.stop()
        // 条目从状态栏移除由 StatusBarRegistry 监听模块开关自动完成，这里只清采样与窗口。
        cancellables.removeAll()
        windowController?.shutdown()
        windowController = nil
    }

    /// 三个监控条目只在首次启动时注册一次，之后由公共状态栏层接管显示与顺序。
    private func registerStatusEntriesIfNeeded() {
        guard statusEntries.isEmpty else { return }
        let entries: [StatusBarEntry] = [
            SystemToolCPUEntry(sampler: sampler),
            SystemToolMEMEntry(sampler: sampler),
            SystemToolNetEntry(sampler: sampler)
        ]
        statusEntries = entries
        entries.forEach { StatusBarRegistry.shared.register($0) }
    }

    func open() {
        guard ModuleRegistry.shared.isEnabled(Self.id) else { return }
        if windowController == nil {
            windowController = SystemToolWindowController(sampler: sampler)
            windowController?.onClose = { [weak self] in
                Task { @MainActor in self?.windowController = nil }
            }
        }
        windowController?.show()
    }

    // MARK: - Menu

    func menuItems() -> [NSMenuItem] {
        let parent = NSMenuItem(title: "PureMac", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("systemTool.root")
        let submenu = NSMenu(title: "PureMac")
        parent.submenu = submenu
        submenu.addItem(menuItem("打开 PureMac…", #selector(openFromMenu), "trash.fill", id: "systemTool.open"))
        submenu.addItem(menuItem("PureMac 设置…", #selector(openSettings), "gearshape", id: "systemTool.settings"))
        return [parent]
    }

    func settingsView() -> AnyView {
        AnyView(SystemToolSettingsView())
    }

    private func menuItem(_ title: String, _ selector: Selector, _ symbol: String, id: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.identifier = NSUserInterfaceItemIdentifier(id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    @objc private func openFromMenu() { open() }
    @objc private func openSettings() { MenuBarController.shared.openSettings(tab: .systemTool) }

}
