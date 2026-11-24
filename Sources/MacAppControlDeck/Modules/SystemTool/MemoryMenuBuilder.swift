import AppKit
import Foundation

/// 菜单栏 MEM 状态项的内存占用下拉菜单（参考腾讯柠檬交互）。
/// 纯 AppKit 构建，点击时一次性采样，不常驻后台任务、不申请任何权限。
enum MemoryMenuBuilder {

    /// 占用大小格式化：B / KB / MB / GB，保留 1 位小数（GB/MB）或整数（KB/B）。
    static func formatBytes(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 KB" }
        let value = Double(bytes)
        switch value {
        case ..<1_024:
            return "\(bytes) B"
        case ..<(1_024 * 1_024):
            return "\(Int((value / 1_024).rounded())) KB"
        case ..<(1_024 * 1_024 * 1_024):
            return String(format: "%.1f MB", value / (1_024 * 1_024))
        default:
            return String(format: "%.1f GB", value / (1_024 * 1_024 * 1_024))
        }
    }

    /// 构建内存菜单。
    /// - Parameters:
    ///   - usedFraction: 总内存占用率 0...1
    ///   - consumers: 按内存降序的应用列表
    ///   - onClose: 点击某行「关闭」的回调（安全校验由调用方 / ProcessTerminationPolicy 负责）
    static func buildMenu(
        usedFraction: Double,
        consumers: [ProcessResourceConsumer],
        onClose: @escaping (ProcessResourceConsumer) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 标题：内存占用 XX%
        let percent = Int((min(1, max(0, usedFraction)) * 100).rounded())
        let titleItem = NSMenuItem()
        let titleView = makeTitleView(text: "内存占用 \(percent)%")
        titleItem.view = titleView
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        if consumers.isEmpty {
            let empty = NSMenuItem(title: "没有可显示的应用", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for consumer in consumers {
                let item = NSMenuItem()
                let canClose = ProcessTerminationPolicy.canTerminate(consumer)
                let row = ProcessMenuRow(consumer: consumer, canClose: canClose, onClose: onClose)
                item.view = row
                item.isEnabled = false // 交互完全由行内的关闭按钮承载
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())
        let tip = NSMenuItem(title: "关闭将直接退出程序，请先保存重要数据", action: nil, keyEquivalent: "")
        tip.isEnabled = false
        menu.addItem(tip)
        return menu
    }

    private static func makeTitleView(text: String) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }
}

/// 菜单中的一行应用：图标 + 名称 + 占用大小 + 关闭按钮。
private final class ProcessMenuRow: NSView {
    private let consumer: ProcessResourceConsumer
    private let onClose: (ProcessResourceConsumer) -> Void

    init(consumer: ProcessResourceConsumer, canClose: Bool, onClose: @escaping (ProcessResourceConsumer) -> Void) {
        self.consumer = consumer
        self.onClose = onClose
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 30))

        let icon = NSImageView(frame: NSRect(x: 8, y: 5, width: 20, height: 20))
        icon.image = ProcessResourceMonitor.iconForPath(consumer.applicationPath)
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)

        let name = NSTextField(labelWithString: consumer.name)
        name.font = NSFont.systemFont(ofSize: 12)
        name.textColor = .labelColor
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.translatesAutoresizingMaskIntoConstraints = false
        addSubview(name)

        let size = NSTextField(labelWithString: MemoryMenuBuilder.formatBytes(consumer.residentBytes))
        size.font = NSFont.systemFont(ofSize: 11)
        size.textColor = .secondaryLabelColor
        size.alignment = .right
        size.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        size.translatesAutoresizingMaskIntoConstraints = false
        addSubview(size)

        let close = NSButton(title: "关闭", target: self, action: #selector(closeTapped))
        close.bezelStyle = .inline
        close.font = NSFont.systemFont(ofSize: 11)
        close.isEnabled = canClose
        close.toolTip = canClose ? "关闭将直接退出程序，请先保存重要数据" : "系统或受保护进程不可退出"
        close.translatesAutoresizingMaskIntoConstraints = false
        addSubview(close)

        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.leadingAnchor.constraint(greaterThanOrEqualTo: name.trailingAnchor, constant: 8),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 40),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func closeTapped() {
        onClose(consumer)
    }
}
