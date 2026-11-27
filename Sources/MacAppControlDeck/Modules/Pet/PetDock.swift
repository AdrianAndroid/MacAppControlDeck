import AppKit
import Combine
import SwiftUI

/// 桌宠底部快捷栏的排序方式。
enum PetDockSortMode: String, CaseIterable, Identifiable {
    case frequency
    case manual
    case recent

    var id: String { rawValue }
    var label: String {
        switch self {
        case .frequency: return "点击频率"
        case .manual: return "手动顺序"
        case .recent: return "最近使用"
        }
    }
}

/// 快捷栏设置：排序、冷却、衰减、显示细节。只影响桌宠栏，不改手机面板顺序。
@MainActor
final class PetDockSettings: ObservableObject {
    static let shared = PetDockSettings()

    private enum Key {
        static let enabled = "pet.dock.enabled"
        static let sort = "pet.dock.sort"
        static let cooldown = "pet.dock.cooldownMinutes"
        static let halfLife = "pet.dock.halfLifeDays"
        static let runningDot = "pet.dock.runningDot"
        static let markLast = "pet.dock.markLastClicked"
    }

    private let defaults: UserDefaults
    private let notifiesCenter: Bool
    private var loading = true

    @Published var enabled: Bool { didSet { save(Key.enabled, enabled) } }
    @Published var sortMode: PetDockSortMode { didSet { save(Key.sort, sortMode.rawValue) } }
    @Published var cooldownMinutes: Int { didSet { save(Key.cooldown, cooldownMinutes) } }
    @Published var halfLifeDays: Int { didSet { save(Key.halfLife, halfLifeDays) } }
    @Published var showRunningDot: Bool { didSet { save(Key.runningDot, showRunningDot) } }
    @Published var markLastClicked: Bool { didSet { save(Key.markLast, markLastClicked) } }

    init(defaults: UserDefaults = .standard, notifiesCenter: Bool = true) {
        self.defaults = defaults
        self.notifiesCenter = notifiesCenter
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        sortMode = PetDockSortMode(rawValue: defaults.string(forKey: Key.sort) ?? "") ?? .frequency
        cooldownMinutes = defaults.object(forKey: Key.cooldown) as? Int ?? 30
        halfLifeDays = defaults.object(forKey: Key.halfLife) as? Int ?? 7
        showRunningDot = defaults.object(forKey: Key.runningDot) as? Bool ?? true
        markLastClicked = defaults.object(forKey: Key.markLast) as? Bool ?? true
        loading = false
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        guard !loading, notifiesCenter else { return }
        PetDockCenter.shared.settingsChanged()
    }
}

/// 启动统计：按 bundleID 记录点击时间戳，用半衰期算权重，最近点过的打折（冷却）。
@MainActor
final class PetDockStats: ObservableObject {
    static let shared = PetDockStats()

    private enum Key {
        static let events = "pet.dock.launchEvents"
        static let lastClicked = "pet.dock.lastClicked"
    }

    private let defaults: UserDefaults
    private(set) var events: [String: [Double]] = [:]
    @Published private(set) var lastClickedID: String?
    private let maxEventsPerApp = 40

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(bundleID: String, at date: Date = Date()) {
        guard !bundleID.isEmpty else { return }
        var list = events[bundleID] ?? []
        list.append(date.timeIntervalSince1970)
        if list.count > maxEventsPerApp { list.removeFirst(list.count - maxEventsPerApp) }
        events[bundleID] = list
        lastClickedID = bundleID
        persist()
    }

    /// 半衰期衰减后的权重；冷却期内再乘 0.4。
    func score(bundleID: String, settings: PetDockSettings = .shared, now: Date = Date()) -> Double {
        guard let list = events[bundleID], !list.isEmpty else { return 0 }
        let nowTS = now.timeIntervalSince1970
        let halfLife = Double(max(1, settings.halfLifeDays)) * 86_400
        var total = 0.0
        for ts in list {
            let age = max(0, nowTS - ts)
            total += pow(0.5, age / halfLife)
        }
        if settings.cooldownMinutes > 0, let last = list.last,
           nowTS - last < Double(settings.cooldownMinutes) * 60 {
            total *= 0.4
        }
        return total
    }

    func isCooling(bundleID: String, settings: PetDockSettings = .shared, now: Date = Date()) -> Bool {
        guard settings.cooldownMinutes > 0,
              let last = events[bundleID]?.last else { return false }
        return now.timeIntervalSince1970 - last < Double(settings.cooldownMinutes) * 60
    }

    func reset() {
        events = [:]
        persist()
        PetDockCenter.shared.statsChanged()
    }

    private func load() {
        lastClickedID = defaults.string(forKey: Key.lastClicked)
        guard let data = defaults.data(forKey: Key.events),
              let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data) else { return }
        events = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: Key.events)
        }
        defaults.set(lastClickedID, forKey: Key.lastClicked)
    }

    /// 最近点击的应用退出后取消标记，避免"明明关了还灰着"。
    func clearLastClickedIfNotRunning() {
        guard let id = lastClickedID,
              !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == id })
        else { return }
        lastClickedID = nil
        persist()
    }
}

/// 桌宠快捷栏：独立小窗口贴在桌宠下方，所有皮肤共用。
@MainActor
final class PetDockCenter {
    static let shared = PetDockCenter()

    private var panel: NSPanel?
    private var hosting: NSHostingView<PetDockView>?
    private var visible = false
    private var lastPetFrame: NSRect = .zero
    private var lastSize: PetSize = .medium
    private var buttonsCancellable: AnyCancellable?

    private init() {
        // 增删应用按钮会改变条宽，需要重排窗口（图标少时收缩并保持居中）。
        buttonsCancellable = DeckState.shared.$buttons
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.visible else { return }
                if DeckState.shared.appButtons.isEmpty { self.hide() } else { self.relayout() }
            }
    }

    func settingsChanged() {
        hosting?.rootView = PetDockView(size: lastSize)
        if visible { relayout() }
    }

    func statsChanged() {
        hosting?.rootView = PetDockView(size: lastSize)
    }

    func show(petFrame: NSRect, size: PetSize) {
        lastPetFrame = petFrame
        lastSize = size
        guard PetDockSettings.shared.enabled else { hide(); return }
        guard !DeckState.shared.appButtons.isEmpty else { hide(); return }
        ensurePanel()
        visible = true
        AppDockOrdering.shared.resortNow()
        relayout()
        panel?.orderFrontRegardless()
    }

    func hide() {
        visible = false
        PetDockTooltip.shared.hide()
        panel?.orderOut(nil)
    }

    /// 悬停提示需要知道快捷栏当前在屏幕上的位置与可滚动偏移。
    var dockFrame: NSRect? { panel?.frame }

    func shutdown() {
        visible = false
        PetDockTooltip.shared.hide()
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    func updatePetFrame(_ frame: NSRect, size: PetSize) {
        lastPetFrame = frame
        lastSize = size
        if visible { relayout() }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        let hosting = NSHostingView(rootView: PetDockView(size: lastSize))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        self.panel = panel
        self.hosting = hosting
    }

    private func relayout() {
        guard let panel else { return }
        PetDockTooltip.shared.hide()
        let metrics = PetDockMetrics(size: lastSize, width: lastPetFrame.width)
        hosting?.rootView = PetDockView(size: lastSize)
        let dockWidth = metrics.dockWidth(count: DeckState.shared.appButtons.count)
        let origin = NSPoint(x: lastPetFrame.minX + (lastPetFrame.width - dockWidth) / 2,
                              y: lastPetFrame.minY - metrics.height)
        panel.setFrame(NSRect(origin: origin,
                              size: NSSize(width: dockWidth, height: metrics.height)),
                       display: true)
        panel.orderFrontRegardless()
    }
}

/// 快捷栏尺寸：宽度跟随桌宠窗口，高度与图标按档位等比，不再有箭头/页点占位。
struct PetDockMetrics {
    let size: PetSize
    let width: CGFloat

    /// 上下内边距，决定条高；留够 8pt 让运行圆点（略微溢出图标 1pt）完整显示。
    var paddingY: CGFloat { 8 }
    /// 左右内边距，比上下略小一点，贴边更紧凑。
    var paddingX: CGFloat { 4 }
    var tile: CGFloat {
        switch size {
        case .small: return 30
        case .medium: return 36
        case .large: return 42
        }
    }
    /// 鼠标操作，不需要为防误触留大缝；2px 紧贴，视觉更像一条 Dock。
    var spacing: CGFloat { 2 }
    var height: CGFloat { tile + paddingY * 2 }
    var gap: CGFloat { 0 }

    /// 图标不足一屏时的内容宽度（左右各留 paddingX）。
    func contentWidth(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * tile + CGFloat(count - 1) * spacing + paddingX * 2
    }

    /// 条宽取「内容宽度」与「桌宠窗口宽度」的较小值：图标少时收缩，图标多时撑满靠拖动滚动。
    func dockWidth(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return min(width, contentWidth(count: count))
    }
}
