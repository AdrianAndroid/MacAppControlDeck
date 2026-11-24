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
    // CPU / MEM / 网速三个独立状态项，可分别点击、单独开关。
    private var cpuStatusItem: NSStatusItem?
    private var memStatusItem: NSStatusItem?
    private var netStatusItem: NSStatusItem?
    /// MEM 菜单专用的一次性进程采样器与菜单引用（不常驻，点击才采样）。
    private let memoryMenuMonitor = ProcessResourceMonitor()
    private var memoryMenu: NSMenu?
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
    private var showNetSpeed: Bool {
        UserDefaults.standard.object(forKey: "systemTool.menubar.showNetSpeed") as? Bool ?? false
    }

    private func observePreferenceChanges() {
        // 设置在别的视图里改动偏好键后，通过通知触发状态项即时重建。
        NotificationCenter.default.publisher(for: .systemToolStatusPreferenceChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildStatusItems() }
            .store(in: &cancellables)
    }

    private func removeStatusItems() {
        [cpuStatusItem, memStatusItem, netStatusItem].compactMap { $0 }.forEach {
            NSStatusBar.system.removeStatusItem($0)
        }
        cpuStatusItem = nil
        memStatusItem = nil
        netStatusItem = nil
        memoryMenu?.cancelTracking()
        memoryMenu = nil
    }

    /// 创建一个独立状态项：单列两行内容 + 各自可点击（点击打开 PureMac）。
    private func makeStatusItem(toolTip: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemTapped)
        item.button?.toolTip = toolTip
        return item
    }

    private func rebuildStatusItems() {
        guard ModuleRegistry.shared.isEnabled(Self.id),
              showCPU || showMEM || showNetSpeed else {
            removeStatusItems()
            return
        }
        removeStatusItems()

        // NSStatusBar 按创建顺序从右往左排列：先创建的靠右。故反序创建以呈现 CPU | MEM | 网速（从左到右）。
        if showNetSpeed {
            netStatusItem = makeStatusItem(toolTip: "PureMac · 实时网速 ↑上传 / ↓下载（点击打开）")
            updateNetStatus()
        }
        if showMEM {
            let item = makeStatusItem(toolTip: "PureMac · 内存占用（点击查看应用排行）")
            item.button?.action = #selector(memStatusItemTapped)
            memStatusItem = item
            updateMEMStatus()
        }
        if showCPU {
            cpuStatusItem = makeStatusItem(toolTip: "PureMac · CPU 使用率（点击打开）")
            updateCPUStatus()
        }

        // 采样值变化时只刷新对应状态项；重建前清空，避免重复订阅累积。
        statusCancellables.removeAll()
        sampler.$cpuUsage.sink { [weak self] _ in self?.updateCPUStatus() }.store(in: &statusCancellables)
        sampler.$memoryUsage.sink { [weak self] _ in self?.updateMEMStatus() }.store(in: &statusCancellables)
        sampler.$uploadBytesPerSec.sink { [weak self] _ in self?.updateNetStatus() }.store(in: &statusCancellables)
        sampler.$downloadBytesPerSec.sink { [weak self] _ in self?.updateNetStatus() }.store(in: &statusCancellables)
    }

    private func updateCPUStatus() {
        guard let button = cpuStatusItem?.button else { return }
        setStatusContent(button, columns: [StatusMetricColumn(top: sampler.cpuPercentText, bottom: "CPU")])
    }

    private func updateMEMStatus() {
        guard let button = memStatusItem?.button else { return }
        setStatusContent(button, columns: [StatusMetricColumn(top: sampler.memoryPercentText, bottom: "MEM")])
    }

    private func updateNetStatus() {
        guard let button = netStatusItem?.button else { return }
        // 网速项：↑上传 / ↓下载两行同字号、同颜色（跟随系统深浅色），只靠箭头区分方向；
        // 数值用定宽格式 + 等宽数字字体，列宽恒定不随速率抖动。
        let netColor: NSColor = .labelColor
        let column = StatusMetricColumn(
            top: "↑ \(sampler.uploadSpeedFixedText)",
            bottom: "↓ \(sampler.downloadSpeedFixedText)",
            topColor: netColor,
            bottomColor: netColor,
            font: StatusMetricView.netSpeedFont,
            fixedWidth: StatusMetricView.netSpeedColumnWidth)
        setStatusContent(button, columns: [column])
    }

    /// 用自定义多列 view 承载文字，避开 NSStatusItem button 对多行 attributedTitle 贴顶裁切的问题。
    private func setStatusContent(_ button: NSStatusBarButton, columns: [StatusMetricColumn]) {
        let metricView: StatusMetricView
        if let existing = button.subviews.first(where: { $0 is StatusMetricView }) as? StatusMetricView {
            metricView = existing
        } else {
            metricView = StatusMetricView(frame: .zero)
            button.addSubview(metricView)
            metricView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                metricView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                metricView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                metricView.topAnchor.constraint(equalTo: button.topAnchor),
                metricView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
        }
        metricView.columns = columns
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
    }

    @objc private func statusItemTapped() { open() }

    /// MEM 项：点击即时采样一次进程内存，构建柠檬式下拉菜单并弹出。
    @objc private func memStatusItemTapped() {
        guard let button = memStatusItem?.button else { return }
        Task { @MainActor in
            let top = await memoryMenuMonitor.sampleMemoryTop(limit: 8)
            let menu = MemoryMenuBuilder.buildMenu(
                usedFraction: sampler.memoryUsage,
                consumers: top,
                onClose: { [weak self] consumer in
                    _ = ProcessTerminationPolicy.terminate(consumer)
                    // 退出后关闭菜单；下次点击会重新采样刷新列表。
                    Task { @MainActor in self?.memoryMenu?.cancelTracking() }
                })
            button.menu = menu
            memoryMenu = menu
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
}

/// 状态项中的一列：上行数值 + 下行标签（网速项则为 ↑/↓ 两行速率）。
struct StatusMetricColumn {
    let top: String
    let bottom: String
    var topColor: NSColor = .labelColor
    var bottomColor: NSColor = .secondaryLabelColor
    /// 指定后两行共用该字体/字号（网速列用等宽数字字体，上下统一）。nil 时上行数值、下行小标签。
    var font: NSFont?
    /// 指定后列宽固定为该值（网速列用，避免数值位数变化引起整条状态项宽度抖动）。
    var fixedWidth: CGFloat?
}

/// 菜单栏状态项的两行指标视图（上数值、下标签），用自定义绘制避免 NSStatusItem
/// 对多行 attributedTitle 的贴顶裁切；内容居中，支持多列（保留列间竖线能力），跟随系统深浅色。
private final class StatusMetricView: NSView {
    var columns: [StatusMetricColumn] = [] {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }

    private let valueFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    private let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
    private let separatorSpacing: CGFloat = 5   // 竖线两侧留白
    private let columnPadding: CGFloat = 3

    /// 网速列：等宽数字字体，上下两行同字号（9pt），避免位数变化抖动、上下字号不一。
    static let netSpeedFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    /// 网速列固定宽度，按最宽模板 "↑ 999.9 M/s" 计算一次，之后恒定。
    static let netSpeedColumnWidth: CGFloat = {
        let w = ("↑ 999.9 M/s" as NSString).size(withAttributes: [.font: netSpeedFont]).width
        return w + 3 * 2 // 与 columnPadding 一致
    }()

    private func fonts(for column: StatusMetricColumn) -> (top: NSFont, bottom: NSFont) {
        if let f = column.font { return (f, f) }
        return (valueFont, labelFont)
    }

    private func columnWidth(_ column: StatusMetricColumn) -> CGFloat {
        if let fixed = column.fixedWidth { return fixed }
        let fonts = fonts(for: column)
        let topW = (column.top as NSString).size(withAttributes: [.font: fonts.top]).width
        let bottomW = (column.bottom as NSString).size(withAttributes: [.font: fonts.bottom]).width
        return max(topW, bottomW) + columnPadding * 2
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !columns.isEmpty else { return }

        let widths = columns.map { columnWidth($0) }
        let separatorW: CGFloat = separatorSpacing * 2 + 1
        let totalW = widths.reduce(0, +) + separatorW * CGFloat(max(0, columns.count - 1))
        var x = (bounds.width - totalW) / 2  // 整块居中

        for (index, column) in columns.enumerated() {
            let w = widths[index]
            let fonts = fonts(for: column)
            let topAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.top, .foregroundColor: column.topColor
            ]
            let bottomAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.bottom, .foregroundColor: column.bottomColor
            ]
            let topSize = (column.top as NSString).size(withAttributes: topAttrs)
            let bottomSize = (column.bottom as NSString).size(withAttributes: bottomAttrs)

            // draw(at:) 的 y 是文字左下角（NSView 原点在左下）。两行对称落在 22pt 内。
            let topY = bounds.height - topSize.height
            let bottomY: CGFloat = 0
            (column.top as NSString).draw(
                at: NSPoint(x: x + (w - topSize.width) / 2, y: topY),
                withAttributes: topAttrs)
            (column.bottom as NSString).draw(
                at: NSPoint(x: x + (w - bottomSize.width) / 2, y: bottomY),
                withAttributes: bottomAttrs)

            x += w
            if index < columns.count - 1 {
                // 竖线：菜单栏高度内画一条淡色分隔线。
                let lineX = x + separatorSpacing
                NSColor.tertiaryLabelColor.setStroke()
                let line = NSBezierPath()
                line.lineWidth = 1
                line.move(to: NSPoint(x: lineX, y: 3))
                line.line(to: NSPoint(x: lineX, y: bounds.height - 3))
                line.stroke()
                x += separatorW
            }
        }
    }

    override var intrinsicContentSize: NSSize {
        guard !columns.isEmpty else { return NSSize(width: 1, height: 22) }
        let widths = columns.reduce(CGFloat(0)) { $0 + columnWidth($1) }
        let separatorW: CGFloat = separatorSpacing * 2 + 1
        let total = widths + separatorW * CGFloat(max(0, columns.count - 1))
        return NSSize(width: max(total, 34), height: 22)
    }
}

extension Notification.Name {
    static let systemToolStatusPreferenceChanged = Notification.Name("systemTool.statusPreferenceChanged")
}
