import Foundation
import Darwin

/// 常驻采样器：只读系统 API 采样 CPU 使用率与内存占用率。
/// 模块启用时启动 2 秒定时器，禁用/App 退出时停止；不申请任何 TCC 权限。
@MainActor
final class SystemSampler: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0      // 0...1
    @Published private(set) var memoryUsage: Double = 0   // 0...1
    @Published private(set) var memoryUsedBytes: UInt64 = 0
    @Published private(set) var memoryTotalBytes: UInt64 = 0

    private var timer: Timer?
    private var previousCPULoad: host_cpu_load_info?

    private static let hostPort = mach_host_self()

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousCPULoad = nil
    }

    deinit { timer?.invalidate() }

    private func sample() {
        sampleCPU()
        sampleMemory()
    }

    private func sampleCPU() {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var load = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &load) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(Self.hostPort, HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let current = load
        if let prev = previousCPULoad {
            let now = Self.cpuTicksArray(current.cpu_ticks)
            let before = Self.cpuTicksArray(prev.cpu_ticks)
            var totalDelta: Double = 0
            var idleDelta: Double = 0
            for i in 0..<Int(CPU_STATE_MAX) where i < now.count {
                let delta = Double(now[i]) - Double(before[i])
                totalDelta += delta
                if i == Int(CPU_STATE_IDLE) { idleDelta += delta }
            }
            if totalDelta > 0 {
                cpuUsage = min(1, max(0, (totalDelta - idleDelta) / totalDelta))
            }
        }
        previousCPULoad = current
    }

    private static func cpuTicksArray(_ ticks: (UInt32, UInt32, UInt32, UInt32)) -> [UInt32] {
        [ticks.0, ticks.1, ticks.2, ticks.3]
    }

    private func sampleMemory() {
        var pageSize: vm_size_t = 0
        host_page_size(Self.hostPort, &pageSize)
        var mstat = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &mstat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(Self.hostPort, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        // macOS 会把空闲内存用作文件缓存（inactive），若把它计入「已用」，占用率会恒接近 100%。
        // 采用活动监视器口径：active + wired + compressor 为实际占用，inactive 视为可回收。
        let usedPages = UInt64(mstat.active_count)
            + UInt64(mstat.wire_count)
            + UInt64(mstat.compressor_page_count)
        let total = ProcessInfo.processInfo.physicalMemory
        memoryUsedBytes = usedPages * UInt64(pageSize)
        memoryTotalBytes = total
        if total > 0 {
            memoryUsage = min(1, max(0, Double(memoryUsedBytes) / Double(total)))
        }
    }

    var cpuPercentText: String { "\(Int((cpuUsage * 100).rounded()))%" }
    var memoryPercentText: String { "\(Int((memoryUsage * 100).rounded()))%" }
}
