import AppKit
import Combine
import SwiftUI

/// 设置页展示用快照。
struct StatusBarEntryInfo: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let moduleID: String
    let visible: Bool
    let available: Bool
}

struct StatusBarGroupSnapshot: Identifiable {
    let id: String          // groupID
    let moduleID: String
    let moduleTitle: String
    let entries: [StatusBarEntryInfo]
}

/// 状态栏公共注册中心：模块注册条目，这里统一决定分组、顺序、开关与渲染。
/// 一个 group 对应一个 NSStatusItem，组内每个条目是一格，各自可点、可各自弹菜单。
@MainActor
final class StatusBarRegistry: ObservableObject {
    static let shared = StatusBarRegistry()

    @Published private(set) var snapshots: [StatusBarGroupSnapshot] = []

    private var entries: [StatusBarEntry] = []
    private var controls: [String: StatusBarGroupControl] = [:]
    private var bag = Set<AnyCancellable>()

    private init() {
        ModuleRegistry.shared.$enabledIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &bag)
        StatusBarStore.shared.$values
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &bag)
    }

    func register(_ entry: StatusBarEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        reload()
    }

    func entry(id: String) -> StatusBarEntry? { entries.first { $0.id == id } }

    func isVisible(_ entryID: String) -> Bool {
        guard let entry = entry(id: entryID) else { return false }
        return StatusBarStore.shared.isVisible(entry)
    }

    func setVisible(_ visible: Bool, entryID: String) {
        guard let entry = entry(id: entryID) else { return }
        StatusBarStore.shared.setVisible(visible, for: entry)
    }

    /// 重建所有分组：先算出每组应显示的条目，再让分组控件刷新。
    func reload() {
        var grouped: [String: [StatusBarEntry]] = [:]
        for entry in entries where entry.isAvailable && StatusBarStore.shared.isVisible(entry) {
            grouped[entry.groupID, default: []].append(entry)
        }
        for (groupID, list) in grouped {
            list.sorted { $0.order < $1.order }
            let control = controls[groupID] ?? StatusBarGroupControl(groupID: groupID)
            controls[groupID] = control
            control.rebuild(entries: list.sorted { $0.order < $1.order })
        }
        for (groupID, control) in controls where grouped[groupID] == nil {
            control.teardown()
            controls.removeValue(forKey: groupID)
        }
        publishSnapshots()
    }

    private func publishSnapshots() {
        var byGroup: [String: [StatusBarEntry]] = [:]
        for entry in entries { byGroup[entry.groupID, default: []].append(entry) }

        snapshots = byGroup.keys.sorted().compactMap { groupID in
            guard let list = byGroup[groupID], let first = list.first else { return nil }
            let moduleTitle = ModuleRegistry.shared.module(id: first.moduleID)?.title ?? first.moduleID
            let infos = list.sorted { $0.order < $1.order }.map { entry in
                StatusBarEntryInfo(id: entry.id,
                                   title: entry.title,
                                   subtitle: entry.subtitle,
                                   moduleID: entry.moduleID,
                                   visible: StatusBarStore.shared.isVisible(entry),
                                   available: entry.isAvailable)
            }
            return StatusBarGroupSnapshot(id: groupID,
                                          moduleID: first.moduleID,
                                          moduleTitle: moduleTitle,
                                          entries: infos)
        }
    }
}

/// 分组控件：一个 NSStatusItem，内部横向摆放各条目的格子。
@MainActor
final class StatusBarGroupControl {
    private let groupID: String
    private var item: NSStatusItem?
    private var cells: [StatusBarCellView] = []

    init(groupID: String) { self.groupID = groupID }

    func rebuild(entries: [StatusBarEntry]) {
        teardown()
        guard !entries.isEmpty else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "MacAppControlDeck.group.\(groupID)"
        item.button?.title = ""
        item.button?.attributedTitle = NSAttributedString(string: "")
        self.item = item

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        for entry in entries {
            let cell = StatusBarCellView(entry: entry)
            cells.append(cell)
            stack.addArrangedSubview(cell)
        }

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp])
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        item.length = max(24, stack.fittingSize.width + 12)
    }

    /// NSStatusBarButton 会吞掉子视图的 mouseDown，这里统一在按钮层做分段命中。
    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        // currentEvent 在部分系统版本里拿不到，回退到屏幕坐标换算，保证分段命中可用。
        var point: NSPoint?
        if let event = NSApp.currentEvent, event.window === sender.window {
            point = sender.convert(event.locationInWindow, from: nil)
        } else if let window = sender.window {
            point = sender.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        }
        guard let location = point else { return }
        let hit = cells.first { cell in
            cell.convert(cell.bounds, to: sender).contains(location)
        }
        hit?.activateEntry()
    }

    func teardown() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        cells.forEach { $0.removeFromSuperview() }
        cells = []
    }
}

/// 只做布局、不参与命中测试的容器：把点击让给外层格子。
private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// 单个格子：承载条目自己的视图，点击交给条目决定弹菜单还是开窗口。
@MainActor
final class StatusBarCellView: NSView {
    private let entry: StatusBarEntry
    private let content: NSView

    init(entry: StatusBarEntry) {
        self.entry = entry
        self.content = entry.makeView()
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let host = PassthroughView()
        host.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(content)
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            content.topAnchor.constraint(equalTo: host.topAnchor),
            content.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        activateEntry()
    }

    var entryID: String { entry.id }

    func activateEntry() {
        NSLog("StatusBar click: %@", entry.id)
        entry.activate(from: self)
    }

    override var intrinsicContentSize: NSSize {
        let size = content.fittingSize
        return NSSize(width: max(size.width, 28), height: 22)
    }
}
