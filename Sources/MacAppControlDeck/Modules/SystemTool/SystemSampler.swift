import Foundation
import Darwin

/// 常驻采样器：只读系统 API 采样 CPU 使用率、内存占用率与实时网速。
/// 模块启用时启动 2 秒定时器，禁用/App 退出时停止；不申请任何 TCC 权限。
@MainActor
final class SystemSampler: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0      // 0...1
    @Published private(set) var memoryUsage: Double = 0   // 0...1
    @Published private(set) var memoryUsedBytes: UInt64 = 0
    @Published private(set) var memoryTotalBytes: UInt64 = 0
    // 实时网速（字节/秒），由累计字节定时差分得到。
    @Published private(set) var uploadBytesPerSec: Double = 0
    @Published private(set) var downloadBytesPerSec: Double = 0

    private var timer: Timer?
    private var previousCPULoad: host_cpu_load_info?
    private var previousNetworkCounters: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: Date?

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
        previousNetworkCounters = nil
        previousNetworkTime = nil
        uploadBytesPerSec = 0
        downloadBytesPerSec = 0
    }

    deinit { timer?.invalidate() }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
    }

    // MARK: - 实时网速

    /// 读取所有活动网络接口的累计收发字节（跳过 loopback 与全零空闲接口）。
    /// 公开 API，零 TCC 权限。返回 (received, sent)。
    nonisolated static func readNetworkCounters() -> (received: UInt64, sent: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let head = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer = head
        while true {
            let ifa = pointer.pointee
            let name = String(cString: ifa.ifa_name)
            // 只统计物理/隧道接口，跳过 lo0 等 loopback。
            if name.hasPrefix("en") || name.hasPrefix("utun"), let data = ifa.ifa_data {
                let info = data.assumingMemoryBound(to: if_data.self).pointee
                received += UInt64(info.ifi_ibytes)
                sent += UInt64(info.ifi_obytes)
            }
            guard let next = ifa.ifa_next else { break }
            pointer = next
        }
        return (received, sent)
    }

    private func sampleNetwork() {
        let now = Date()
        let current = Self.readNetworkCounters()
        defer {
            previousNetworkCounters = current
            previousNetworkTime = now
        }
        guard let previous = previousNetworkCounters, let previousTime = previousNetworkTime else { return }
        let elapsed = now.timeIntervalSince(previousTime)
        guard elapsed > 0 else { return }

        // 累计字段回绕或接口重置时，本次差值记 0，不产生负数。
        let receivedDelta = current.received >= previous.received ? current.received - previous.received : 0
        let sentDelta = current.sent >= previous.sent ? current.sent - previous.sent : 0
        downloadBytesPerSec = Double(receivedDelta) / elapsed
        uploadBytesPerSec = Double(sentDelta) / elapsed
    }

    /// 把字节/秒格式化为柠檬风格单位：B/s → K/s → M/s，1 位小数，无数据显示 0 K/s。
    nonisolated static func formatSpeed(_ bytesPerSec: Double) -> String {
        guard bytesPerSec.isFinite, bytesPerSec > 0 else { return "0 K/s" }
        let kilo = 1_024.0
        let mega = kilo * kilo
        switch bytesPerSec {
        case ..<kilo:
            return "\(Int(bytesPerSec.rounded())) B/s"
        case ..<mega:
            return String(format: "%.1f K/s", bytesPerSec / kilo)
        default:
            return String(format: "%.1f M/s", bytesPerSec / mega)
        }
    }

    /// 菜单栏定宽格式：数值用 figure space (U+2007，与数字等宽) 右对齐到 5 字符
    ///（"   0.0" ~ "999.9"），单位固定 3 字符（B/s / K/s / M/s / G/s）。
    /// 配合等宽数字字体使整串宽度恒定，避免网速列随数值位数变化而抖动。
    nonisolated static func formatSpeedFixed(_ bytesPerSec: Double) -> String {
        let units = ["B/s", "K/s", "M/s", "G/s"]
        let valid = bytesPerSec.isFinite && bytesPerSec > 0
        var value = valid ? bytesPerSec : 0
        // 零值/负值沿用既有约定显示 K/s（idx=1）；有效值从 B/s（idx=0）起。
        var idx = valid ? 0 : 1
        // 逐档换算，保证数值恒 < 1000，格式化后最多 5 字符（如 999.9）。
        while value >= 999.95 && idx < units.count - 1 {
            value /= 1_024
            idx += 1
        }
        // 最高档仍超限（极端值，实际不可达）时封顶，确保数值恒为 5 字符。
        if value > 999.9 { value = 999.9 }
        let padded = String(format: "%5.1f", value)
            .replacingOccurrences(of: " ", with: "\u{2007}")
        return "\(padded) \(units[idx])"
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
    var uploadSpeedText: String { Self.formatSpeed(uploadBytesPerSec) }
    var downloadSpeedText: String { Self.formatSpeed(downloadBytesPerSec) }
    /// 菜单栏专用：定宽文本，位数变化不抖动。
    var uploadSpeedFixedText: String { Self.formatSpeedFixed(uploadBytesPerSec) }
    var downloadSpeedFixedText: String { Self.formatSpeedFixed(downloadBytesPerSec) }
}
