import AppKit
import Combine

/// PureMac 在状态栏的三个条目：CPU / MEM / 网速。
/// 它们只描述「显示什么、点开什么」，分组、顺序、开关由 StatusBarRegistry 统一管理。

@MainActor
class SystemToolMetricEntry {
    let groupID = SystemToolModule.id
    var moduleID: String { SystemToolModule.id }
    var isAvailable: Bool { ModuleRegistry.shared.isEnabled(moduleID) }

    let sampler: SystemSampler
    weak var metricView: StatusBarMetricView?
    var bag = Set<AnyCancellable>()

    init(sampler: SystemSampler) { self.sampler = sampler }

    func makeView() -> NSView {
        let view = StatusBarMetricView()
        metricView = view
        refresh()
        return view
    }

    func refresh() {}
    func activate(from view: NSView) { SystemToolModule.shared.open() }
}

@MainActor
final class SystemToolCPUEntry: SystemToolMetricEntry, StatusBarEntry {
    let id = "systemTool.cpu"
    let order = 0
    let title = "CPU 使用率"
    let subtitle = "组内第 1 格"
    let defaultVisible = true

    override init(sampler: SystemSampler) {
        super.init(sampler: sampler)
        sampler.$cpuUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
    }

    override func refresh() {
        metricView?.columns = [StatusBarMetricColumn(top: sampler.cpuPercentText, bottom: "CPU")]
    }
}

@MainActor
final class SystemToolMEMEntry: SystemToolMetricEntry, StatusBarEntry {
    let id = "systemTool.mem"
    let order = 1
    let title = "内存占用"
    let subtitle = "组内第 2 格 · 点击查看应用排行"
    let defaultVisible = true

    private let memoryMenuMonitor = ProcessResourceMonitor()
    private var memoryMenu: NSMenu?

    override init(sampler: SystemSampler) {
        super.init(sampler: sampler)
        sampler.$memoryUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
    }

    override func refresh() {
        metricView?.columns = [StatusBarMetricColumn(top: sampler.memoryPercentText, bottom: "MEM")]
    }

    override func activate(from view: NSView) {
        Task { @MainActor in
            let top = await memoryMenuMonitor.sampleMemoryTop(limit: 8)
            let menu = MemoryMenuBuilder.buildMenu(
                usedFraction: sampler.memoryUsage,
                consumers: top,
                onClose: { [weak self] consumer in
                    _ = ProcessTerminationPolicy.terminate(consumer)
                    Task { @MainActor in self?.memoryMenu?.cancelTracking() }
                })
            memoryMenu = menu
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
        }
    }
}

@MainActor
final class SystemToolNetEntry: SystemToolMetricEntry, StatusBarEntry {
    let id = "systemTool.net"
    let order = 2
    let title = "实时网速"
    let subtitle = "组内第 3 格 · ↑上传 / ↓下载"
    let defaultVisible = false

    override init(sampler: SystemSampler) {
        super.init(sampler: sampler)
        sampler.$uploadBytesPerSec
            .merge(with: sampler.$downloadBytesPerSec)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
    }

    override func refresh() {
        let column = StatusBarMetricColumn(
            top: "↑ \(sampler.uploadSpeedFixedText)",
            bottom: "↓ \(sampler.downloadSpeedFixedText)",
            topColor: .labelColor,
            bottomColor: .labelColor,
            font: StatusBarMetricView.netSpeedFont,
            fixedWidth: StatusBarMetricView.netSpeedColumnWidth)
        metricView?.columns = [column]
    }
}
