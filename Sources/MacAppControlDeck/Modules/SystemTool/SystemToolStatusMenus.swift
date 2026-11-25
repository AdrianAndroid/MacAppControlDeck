import AppKit

/// 菜单栏 CPU / 网速状态项的下拉菜单。
/// 三个监控条目拆成独立状态项后，每个图标点开自己的菜单；仍是点击时一次性采样，
/// 不常驻后台任务、不申请任何权限。
@MainActor
enum CPUMenuBuilder {

    static func buildMenu(cpuFraction: Double,
                          consumers: [ProcessResourceConsumer],
                          onOpen: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let percent = Int((min(1, max(0, cpuFraction)) * 100).rounded())
        menu.addItem(titleItem(text: "CPU 占用 \(percent)%"))
        menu.addItem(.separator())

        if consumers.isEmpty {
            menu.addItem(disabledItem(text: "没有可显示的应用"))
        } else {
            for consumer in consumers {
                let value = consumer.cpuFraction.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
                menu.addItem(rowItem(consumer: consumer, value: value))
            }
        }

        menu.addItem(.separator())
        menu.addItem(openItem(title: "打开 PureMac…", handler: onOpen))
        return menu
    }
}

@MainActor
enum NetMenuBuilder {

    static func buildMenu(upload: String,
                          download: String,
                          onOpen: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(titleItem(text: "实时网速"))
        menu.addItem(.separator())
        menu.addItem(disabledItem(text: "↑ 上传 \(upload)"))
        menu.addItem(disabledItem(text: "↓ 下载 \(download)"))
        menu.addItem(.separator())
        menu.addItem(openItem(title: "打开 PureMac…", handler: onOpen))
        return menu
    }
}

// MARK: - 公共小构件

@MainActor
private func titleItem(text: String) -> NSMenuItem {
    let item = NSMenuItem()
    item.view = MetricMenuRow(title: text, value: nil, icon: nil, isTitle: true, width: 220)
    item.isEnabled = false
    return item
}

@MainActor
private func disabledItem(text: String) -> NSMenuItem {
    let item = NSMenuItem()
    item.view = MetricMenuRow(title: text, value: nil, icon: nil, isTitle: false, width: 220)
    item.isEnabled = false
    return item
}

@MainActor
private func rowItem(consumer: ProcessResourceConsumer, value: String) -> NSMenuItem {
    let item = NSMenuItem()
    item.view = MetricMenuRow(title: consumer.name,
                              value: value,
                              icon: ProcessResourceMonitor.iconForPath(consumer.applicationPath),
                              isTitle: false,
                              width: 260)
    item.isEnabled = false
    return item
}

@MainActor
private func openItem(title: String, handler: @escaping () -> Void) -> NSMenuItem {
    ClosureMenuItem(title: title, handler: handler)
}

/// 自己当自己的 target：菜单持有 item，item 持有闭包，不需要额外的生命周期管理。
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self
        action = #selector(fire)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func fire() { handler() }
}

/// 菜单里的一行：可选图标 + 名称 + 右侧数值。纯绘制，不参与点击。
@MainActor
private final class MetricMenuRow: NSView {
    init(title: String, value: String?, icon: NSImage?, isTitle: Bool, width: CGFloat) {
        let height: CGFloat = isTitle ? 24 : 24
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var leading: CGFloat = 10
        if let icon {
            let iconView = NSImageView(frame: NSRect(x: 8, y: (height - 18) / 2, width: 18, height: 18))
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            addSubview(iconView)
            leading = 30
        }

        let label = NSTextField(labelWithString: title)
        label.font = isTitle
            ? NSFont.systemFont(ofSize: 13, weight: .semibold)
            : NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        if let value {
            let valueLabel = NSTextField(labelWithString: value)
            valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            valueLabel.textColor = .secondaryLabelColor
            valueLabel.alignment = .right
            valueLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(valueLabel)
            NSLayoutConstraint.activate([
                valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
            ])
        }

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }
}
