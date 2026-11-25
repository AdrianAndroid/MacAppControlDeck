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

/// 设置页分组快照：`groupID` 只用于设置页归类，不再合并成同一条状态项。
struct StatusBarGroupSnapshot: Identifiable {
    let id: String          // groupID
    let moduleID: String
    let moduleTitle: String
    let entries: [StatusBarEntryInfo]
}

/// 状态栏公共注册中心：模块只注册条目，这里统一决定顺序、开关与渲染。
/// 每个条目一个独立 `NSStatusItem`，各自可点、各自弹自己的菜单。
@MainActor
final class StatusBarRegistry: ObservableObject {
    static let shared = StatusBarRegistry()

    @Published private(set) var snapshots: [StatusBarGroupSnapshot] = []

    private var entries: [StatusBarEntry] = []
    private var controls: [String: StatusBarItemControl] = [:]
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

    /// 每个可见条目一条状态项，按 `order` 顺序创建；不再出现的条目拆掉自己的状态项。
    func reload() {
        let visible = entries
            .filter { $0.isAvailable && StatusBarStore.shared.isVisible($0) }
            .sorted { lhs, rhs in
                if lhs.order == rhs.order { return lhs.id < rhs.id }
                return lhs.order < rhs.order
            }

        let wanted = Set(visible.map(\.id))
        for (id, control) in controls where !wanted.contains(id) {
            control.teardown()
            controls.removeValue(forKey: id)
        }
        // 创建顺序不影响最终左→右位置：系统按 autosaveName 记住的位置摆放，
        // 只有新名字的条目才会排到默认位置。
        for entry in visible {
            if let control = controls[entry.id], control.isBuilt { continue }
            let control = controls[entry.id] ?? StatusBarItemControl(entryID: entry.id)
            controls[entry.id] = control
            control.rebuild(entry: entry)
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

/// 单条目状态项：一个 `NSStatusItem` 只承载一个条目，点击由该条目自己决定弹什么菜单。
@MainActor
final class StatusBarItemControl {
    /// 格子与按钮边缘的内缩。保持 0：和最初的独立状态项一致，`variableLength`
    /// 会把状态项收到内容宽度，三条指标之间只留下系统本身的窄间距。
    private static let horizontalPadding: CGFloat = 0

    let entryID: String
    private var item: NSStatusItem?
    private var cell: StatusBarCellView?

    var isBuilt: Bool { item != nil }

    init(entryID: String) { self.entryID = entryID }

    func rebuild(entry: StatusBarEntry) {
        teardown()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 每个条目各自持久化位置，⌘-拖动排位后重启仍保持。
        // v3：分组/首版 length 时代的位置都作废，按当前顺序重新落位一次。
        item.autosaveName = "MacAppControlDeck.status.v3.\(entry.id)"
        guard let button = item.button else { return }
        self.item = item

        button.title = ""
        button.target = self
        button.action = #selector(statusButtonClicked)
        button.sendAction(on: [.leftMouseUp])

        let cell = StatusBarCellView(entry: entry)
        cell.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(cell)
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Self.horizontalPadding),
            cell.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Self.horizontalPadding),
            cell.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        self.cell = cell

        // 不写死 length：`variableLength` 让状态项收到内容宽度，条目之间才挨得紧；
        // 显式赋 length 会给每一项加上自己的留白，三条看起来就散了。
    }

    /// 一个状态项只有一格，直接在按钮层转发给条目，不再做分段命中。
    @objc private func statusButtonClicked() {
        cell?.activateEntry()
    }

    func teardown() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        cell?.removeFromSuperview()
        cell = nil
    }
}

/// 单个格子：承载条目自己的视图，点击交给条目决定弹菜单还是开窗口。
@MainActor
final class StatusBarCellView: NSView {
    private let entry: StatusBarEntry
    let content: NSView

    init(entry: StatusBarEntry) {
        self.entry = entry
        self.content = entry.makeView()
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        activateEntry()
    }

    var entryID: String { entry.id }

    func activateEntry() {
        entry.activate(from: self)
    }

    override var intrinsicContentSize: NSSize {
        let size = content.fittingSize
        return NSSize(width: max(size.width, 28), height: 22)
    }
}
