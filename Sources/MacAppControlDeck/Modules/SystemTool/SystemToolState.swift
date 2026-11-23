import Foundation
import SwiftUI
import AppKit

/// 按需扫描/清理的统一状态与动作层。用完即弃，不常驻扫描对象。
@MainActor
final class SystemToolState: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var currentPath = ""
    @Published var junkResults: [CategoryResult] = []
    @Published var largeFiles: [CleanableItem] = []
    @Published var statusMessage = "就绪"
    @Published var lastScanDate: Date?
    @Published var hasFullDiskAccess = false
    @Published var lastCleanResult: TrashResult?

    let sampler: SystemSampler

    private let engine = ScanEngine()
    private let trash = SystemTrashService()
    private let processMonitor = ProcessResourceMonitor()
    private var scanCancelled = false

    func cancelScan() {
        scanCancelled = true
        statusMessage = "已取消"
        isScanning = false
    }

    init(sampler: SystemSampler) {
        self.sampler = sampler
        self.hasFullDiskAccess = SystemPermissionGate.hasFullDiskAccess()
    }

    // MARK: - Scans

    func scanJunk(categories: [CleaningCategory]) async {
        guard !isScanning else { return }
        scanCancelled = false
        isScanning = true
        statusMessage = "扫描中"
        scanProgress = 0
        var results: [CategoryResult] = []
        for (index, category) in categories.enumerated() {
            if scanCancelled || Task.isCancelled { break }
            currentPath = category.description
            let result = await engine.scanCategory(category) { [weak self] path in
                Task { @MainActor in self?.currentPath = path }
            }
            if scanCancelled { break }
            results.append(result)
            scanProgress = Double(index + 1) / Double(categories.count)
        }
        if !scanCancelled {
            junkResults = results
            lastScanDate = Date()
            statusMessage = "就绪"
        }
        isScanning = false
        hasFullDiskAccess = SystemPermissionGate.hasFullDiskAccess()
    }

    func scanLargeFiles() async {
        guard !isScanning else { return }
        scanCancelled = false
        isScanning = true
        statusMessage = "扫描大文件中"
        currentPath = ""
        let result = await engine.scanCategory(.largeFiles) { [weak self] path in
            Task { @MainActor in self?.currentPath = path }
        }
        if !scanCancelled {
            largeFiles = result.items
            lastScanDate = Date()
            statusMessage = "就绪"
        }
        isScanning = false
    }

    // MARK: - Clean

    @discardableResult
    func clean(items: [CleanableItem], permanently: Set<String> = []) async -> TrashResult {
        statusMessage = "清理中"
        let result = await trash.clean(items, permanentPaths: permanently) { [weak self] progress in
            Task { @MainActor in self?.scanProgress = progress }
        }
        statusMessage = "就绪"
        // 清理后按「原始路径」移除对应行（cleanedPaths 记录的就是原始路径）
        junkResults = junkResults.map { var r = $0; r.items.removeAll { result.cleanedPaths.contains($0.path) }; return r }
        largeFiles.removeAll { result.cleanedPaths.contains($0.path) }
        lastCleanResult = result
        return result
    }

    func selectAll(in category: CleaningCategory, selected: Bool) {
        guard let idx = junkResults.firstIndex(where: { $0.category == category }) else { return }
        for i in junkResults[idx].items.indices where !junkResults[idx].items[i].selectOnlyByHand {
            junkResults[idx].items[i].isSelected = selected
        }
    }

    // MARK: - Disk

    func diskInfo() -> DiskInfo {
        var info = DiskInfo()
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return info }
        if let total = attrs[.systemSize] as? Int64 { info.totalSpace = total }
        if let free = attrs[.systemFreeSize] as? Int64 { info.freeSpace = free }
        info.usedSpace = info.totalSpace - info.freeSpace
        return info
    }

    // MARK: - Processes

    func setProcessMonitoring(_ active: Bool) { processMonitor.setActive(active) }
    var processMonitorObject: ProcessResourceMonitor { processMonitor }
}
