import Combine
import Foundation

/// 应用排序的唯一权威：桌宠底部快捷栏与手机主屏共用。
///
/// - 统计与设置仍复用 `PetDockSettings` / `PetDockStats` 的 `pet.dock.*` 键；
/// - 点击后冻结当前顺序 5 秒，避免按钮在手指 / 鼠标下方跳位；
/// - 冻结到期、切换排序模式、清空统计或增删应用时更新 `revision`，
///   桌宠视图重绘，手机面板下一次 2 秒轮询拿到同一份顺序。
@MainActor
final class AppDockOrdering: ObservableObject {
    static let shared = AppDockOrdering()

    /// 顺序快照版本。视图观察它来触发重绘；手机端通过 `/api/buttons` 自然拉取。
    @Published private(set) var revision = 0

    private let settings: PetDockSettings
    private let stats: PetDockStats
    private let appsProvider: @MainActor () -> [ButtonConfig]
    private let now: () -> Date
    private let holdDuration: TimeInterval

    private var frozenIDs: [String]?
    private var unfreezeWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(settings: PetDockSettings? = nil,
         stats: PetDockStats? = nil,
         appsProvider: (@MainActor () -> [ButtonConfig])? = nil,
         now: @escaping () -> Date = Date.init,
         holdDuration: TimeInterval = 5) {
        let settings = settings ?? .shared
        let stats = stats ?? .shared
        self.settings = settings
        self.stats = stats
        self.appsProvider = appsProvider ?? { DeckState.shared.appButtons }
        self.now = now
        self.holdDuration = holdDuration

        settings.$sortMode.dropFirst()
            .sink { [weak self] _ in self?.resortNow() }
            .store(in: &cancellables)
        settings.$cooldownMinutes.dropFirst()
            .sink { [weak self] _ in self?.resortNow() }
            .store(in: &cancellables)
        settings.$halfLifeDays.dropFirst()
            .sink { [weak self] _ in self?.resortNow() }
            .store(in: &cancellables)
    }

    /// 当前排序结果。输入应为配置顺序（`DeckState.appButtons` / `store.sortedButtons()` 的应用子集）。
    func orderedApps(from apps: [ButtonConfig]) -> [ButtonConfig] {
        let sorted = Self.sorted(apps,
                                 mode: settings.sortMode,
                                 stats: stats,
                                 settings: settings,
                                 now: now())
        guard let frozenIDs else { return sorted }

        let held = Set(frozenIDs)
        let byID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        var result = frozenIDs.compactMap { byID[$0] }
        result.append(contentsOf: sorted.filter { !held.contains($0.id) })
        return result
    }

    /// 记录一次应用点击；首次点击时冻结当前顺序，5 秒无新点击后解冻。
    func recordClick(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        if frozenIDs == nil {
            frozenIDs = Self.sorted(appsProvider(),
                                    mode: settings.sortMode,
                                    stats: stats,
                                    settings: settings,
                                    now: now())
                .map(\.id)
        }
        stats.record(bundleID: bundleID)
        scheduleUnfreeze()
    }

    /// 立即重排（切换排序模式、增删应用、清空统计时使用）。
    func resortNow() {
        unfreezeWork?.cancel()
        unfreezeWork = nil
        frozenIDs = nil
        revision &+= 1
    }

    func resetStats() {
        stats.reset()
        resortNow()
    }

    var isHoldingOrder: Bool { frozenIDs != nil }

    // MARK: - 排序

    static func sorted(_ apps: [ButtonConfig],
                       mode: PetDockSortMode,
                       stats: PetDockStats,
                       settings: PetDockSettings,
                       now: Date) -> [ButtonConfig] {
        switch mode {
        case .manual:
            return apps
        case .recent:
            let indexOf = Dictionary(uniqueKeysWithValues: apps.enumerated().map { ($0.element.id, $0.offset) })
            return apps.sorted { lhs, rhs in
                let l = stats.events[lhs.bundleID]?.last ?? 0
                let r = stats.events[rhs.bundleID]?.last ?? 0
                if l == r { return (indexOf[lhs.id] ?? 0) < (indexOf[rhs.id] ?? 0) }
                return l > r
            }
        case .frequency:
            let indexOf = Dictionary(uniqueKeysWithValues: apps.enumerated().map { ($0.element.id, $0.offset) })
            return apps.sorted { lhs, rhs in
                let l = stats.score(bundleID: lhs.bundleID, settings: settings, now: now)
                let r = stats.score(bundleID: rhs.bundleID, settings: settings, now: now)
                if abs(l - r) < 0.0001 { return (indexOf[lhs.id] ?? 0) < (indexOf[rhs.id] ?? 0) }
                return l > r
            }
        }
    }

    // MARK: - 冻结

    private func scheduleUnfreeze() {
        unfreezeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.frozenIDs != nil else { return }
                self.frozenIDs = nil
                self.unfreezeWork = nil
                self.revision &+= 1
            }
        }
        unfreezeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }
}
