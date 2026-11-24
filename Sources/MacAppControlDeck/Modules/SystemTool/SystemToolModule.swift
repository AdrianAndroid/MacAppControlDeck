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
    var summary: String { "垃圾清理、应用卸载、大文件与重复文件、进程退出、菜单栏 CPU/MEM 监控。" }
    var systemImage: String { "trash.fill" }
    var defaultEnabled: Bool { true }
    var supportsResidency: Bool { false }

    let sampler = SystemSampler()
    private var windowController: SystemToolWindowController?
    private var cpuStatusItem: NSStatusItem?
    private var memStatusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var statusCancellables = Set<AnyCancellable>()

    // MARK: - FeatureModule lifecycle

    func start() {
        sampler.start()
        rebuildStatusItems()
        observePreferenceChanges()
    }

    func stop() {
        sampler.stop()
        removeStatusItems()
        statusCancellables.removeAll()
        cancellables.removeAll()
        windowController?.shutdown()
        windowController = nil
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

    // MARK: - Status bar items

    private var showCPU: Bool {
        UserDefaults.standard.object(forKey: "systemTool.menubar.showCPU") as? Bool ?? true
    }
    private var showMEM: Bool {
        UserDefaults.standard.object(forKey: "systemTool.menubar.showMEM") as? Bool ?? true
    }

    private func observePreferenceChanges() {
        // 设置在别的视图里改动偏好键后，通过通知触发状态项即时重建。
        NotificationCenter.default.publisher(for: .systemToolStatusPreferenceChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildStatusItems() }
            .store(in: &cancellables)
    }

    private func removeStatusItems() {
        cpuStatusItem.map { NSStatusBar.system.removeStatusItem($0) }
        memStatusItem.map { NSStatusBar.system.removeStatusItem($0) }
        cpuStatusItem = nil
        memStatusItem = nil
    }

    private func rebuildStatusItems() {
        guard ModuleRegistry.shared.isEnabled(Self.id) else {
            removeStatusItems()
            return
        }
        removeStatusItems()

        // NSStatusItem 后创建的会排在左侧。设计图 ② 定稿为「CPU 在左、MEM 在右」，
        // 因此先创建 MEM、再创建 CPU，保证视觉顺序与定稿一致。
        if showMEM {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(statusItemTapped)
            item.button?.toolTip = "PureMac · 内存占用（点击打开）"
            memStatusItem = item
            updateMEMStatus()
        }
        if showCPU {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(statusItemTapped)
            item.button?.toolTip = "PureMac · CPU 占用（点击打开）"
            cpuStatusItem = item
            updateCPUStatus()
        }

        // 采样值变化时更新两个状态项的两行标题；重建前清空，避免重复订阅累积。
        statusCancellables.removeAll()
        sampler.$cpuUsage.sink { [weak self] _ in self?.updateCPUStatus() }.store(in: &statusCancellables)
        sampler.$memoryUsage.sink { [weak self] _ in self?.updateMEMStatus() }.store(in: &statusCancellables)
    }

    private func updateCPUStatus() {
        guard let button = cpuStatusItem?.button else { return }
        button.attributedTitle = twoLineTitle(value: sampler.cpuPercentText, label: "CPU")
    }

    private func updateMEMStatus() {
        guard let button = memStatusItem?.button else { return }
        button.attributedTitle = twoLineTitle(value: sampler.memoryPercentText, label: "MEM")
    }

    /// 仿柠檬分栏形态：上数值（大）、下标签（小、次要色）。
    private func twoLineTitle(value: String, label: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: value, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]))
        result.append(NSAttributedString(string: "\n\(label)", attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        return result
    }

    @objc private func statusItemTapped() { open() }
}

extension Notification.Name {
    static let systemToolStatusPreferenceChanged = Notification.Name("systemTool.statusPreferenceChanged")
}
