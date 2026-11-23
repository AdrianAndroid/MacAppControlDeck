import Foundation
import SwiftUI
import AppKit
import Combine

enum SystemToolPhase: Equatable {
    case idle, scanning, cleaning
}

enum SystemToolOverviewCard: String, CaseIterable, Identifiable {
    case systemJunk, userCache, devCaches, largeFiles, duplicates, trash

    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemJunk: return "系统垃圾"
        case .userCache: return "用户缓存"
        case .devCaches: return "开发缓存"
        case .largeFiles: return "大文件"
        case .duplicates: return "重复文件"
        case .trash: return "废纸篓"
        }
    }
    var icon: String {
        switch self {
        case .systemJunk: return "gearshape.fill"
        case .userCache: return "internaldrive.fill"
        case .devCaches: return "wrench.and.screwdriver.fill"
        case .largeFiles: return "doc.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .trash: return "trash.fill"
        }
    }
    var color: Color {
        switch self {
        case .systemJunk: return .purple
        case .userCache: return .blue
        case .devCaches: return .green
        case .largeFiles: return .orange
        case .duplicates: return .pink
        case .trash: return .red
        }
    }
    var target: SystemToolTab {
        switch self {
        case .systemJunk, .userCache, .devCaches, .trash: return .junk
        case .largeFiles: return .large
        case .duplicates: return .duplicate
        }
    }
}

struct SystemToolOverviewSummary {
    var scanned = false
    var count = 0
    var size: Int64 = 0
}

/// 按需扫描 / 清理 / 卸载的统一状态与动作层。
/// 所有页签共用这一份状态：状态栏三态、清理结果统计、跨页选中都从这里取。
@MainActor
final class SystemToolState: ObservableObject {

    // MARK: - 通用状态
    @Published var phase: SystemToolPhase = .idle
    @Published var scanProgress: Double = 0
    @Published var currentPath = ""
    @Published var statusMessage = "就绪"
    @Published var lastScanDate: Date?
    @Published var hasFullDiskAccess = false
    @Published var lastCleanResult: TrashResult?
    @Published var activeTab: SystemToolTab = .overview

    let sampler: SystemSampler

    private let engine = ScanEngine()
    private let trash = SystemTrashService()
    private let processMonitor = ProcessResourceMonitor()
    private var scanCancelled = false
    private var duplicateTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?
    /// 进程监视器是内嵌的 ObservableObject；SwiftUI 不会自动观察嵌套对象，
    /// 这里把它的变化转发为自身的 objectWillChange，进程页才会刷新。
    private var monitorCancellable: AnyCancellable?

    // MARK: - 垃圾 / 大文件
    @Published var junkResults: [CategoryResult] = []
    @Published var largeFiles: [CleanableItem] = []

    // MARK: - 重复文件
    @Published var duplicateRoot: URL
    @Published var duplicateResult: DuplicateScanResult?
    @Published var duplicateSelected: Set<URL> = []
    @Published var duplicateProgress: DuplicateScanProgress?
    @Published var duplicateError: String?
    @Published var duplicateScanning = false

    // MARK: - 卸载
    @Published var installedApps: [AppPathFinder.AppInfo] = []
    @Published var selectedApp: AppPathFinder.AppInfo?
    @Published var highConfidenceResiduals: [URL] = []
    @Published var reviewResiduals: [URL] = []
    @Published var checkedHigh: Set<URL> = []
    @Published var checkedReview: Set<URL> = []
    @Published var scanningResiduals = false
    @Published var selectedAppSize: Int64 = 0

    private static let duplicateRootKey = "systemTool.cleaning.duplicateScanRoot"

    init(sampler: SystemSampler) {
        self.sampler = sampler
        if let saved = UserDefaults.standard.string(forKey: Self.duplicateRootKey), !saved.isEmpty {
            duplicateRoot = URL(fileURLWithPath: saved)
        } else {
            duplicateRoot = FileManager.default.homeDirectoryForCurrentUser
        }
        hasFullDiskAccess = SystemPermissionGate.hasFullDiskAccess()
        monitorCancellable = processMonitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.objectWillChange.send() }
    }

    // MARK: - 取消 / 停止

    func cancelScan() {
        scanCancelled = true
        duplicateTask?.cancel()
        duplicateScanning = false
        phase = .idle
        scanProgress = 0
        currentPath = ""
        statusMessage = "已取消 · 结果可能不完整"
    }

    func stopCleaning() {
        cleanTask?.cancel()
        statusMessage = "已停止清理"
    }

    // MARK: - 扫描（垃圾 / 大文件）

    func scanJunk(categories: [CleaningCategory]) async {
        guard phase == .idle, !categories.isEmpty else { return }
        scanCancelled = false
        lastCleanResult = nil
        phase = .scanning
        statusMessage = "扫描中"
        scanProgress = 0
        var results: [CategoryResult] = []
        for (index, category) in categories.enumerated() {
            if scanCancelled { break }
            currentPath = category.description
            let result = await engine.scanCategory(category) { [weak self] path in
                Task { @MainActor in self?.currentPath = path }
            }
            if scanCancelled { break }
            results.append(result)
            scanProgress = Double(index + 1) / Double(categories.count)
        }
        if !scanCancelled {
            // 安全硬规则：扫描结果一律默认零选中，禁止「扫完即可一键删」。
            // 上游 ScanEngine 的 scanDirectory 默认 isSelected = true，这里统一清零。
            junkResults = results.map { result in
                var copy = result
                for i in copy.items.indices { copy.items[i].isSelected = false }
                return copy
            }
            lastScanDate = Date()
            statusMessage = "就绪 · 共扫描 \(results.reduce(0) { $0 + $1.itemCount }) 项"
        }
        phase = .idle
        currentPath = ""
        hasFullDiskAccess = SystemPermissionGate.hasFullDiskAccess()
    }

    func scanLargeFiles() async {
        guard phase == .idle else { return }
        scanCancelled = false
        lastCleanResult = nil
        phase = .scanning
        statusMessage = "扫描大文件中"
        scanProgress = 0
        let result = await engine.scanCategory(.largeFiles) { [weak self] path in
            Task { @MainActor in self?.currentPath = path }
        }
        if !scanCancelled {
            largeFiles = result.items.map { item in
                var copy = item
                copy.isSelected = false
                return copy
            }
            lastScanDate = Date()
            statusMessage = "就绪 · 找到 \(result.items.count) 个大文件"
        }
        phase = .idle
        currentPath = ""
        hasFullDiskAccess = SystemPermissionGate.hasFullDiskAccess()
    }

    // MARK: - 扫描（重复文件）

    func setDuplicateRoot(_ url: URL) {
        duplicateRoot = url
        UserDefaults.standard.set(url.path, forKey: Self.duplicateRootKey)
        duplicateResult = nil
        duplicateSelected.removeAll()
        duplicateError = nil
    }

    /// 设置页可能直接写入偏好键；切回重复文件页时重新读取，避免两处不一致。
    func refreshDuplicateRoot() {
        let path = UserDefaults.standard.string(forKey: Self.duplicateRootKey) ?? NSHomeDirectory()
        let url = URL(fileURLWithPath: path)
        guard url != duplicateRoot else { return }
        duplicateRoot = url
        duplicateResult = nil
        duplicateSelected.removeAll()
    }

    func scanDuplicates() {
        guard !duplicateScanning, phase == .idle else { return }
        duplicateTask?.cancel()
        duplicateScanning = true
        duplicateError = nil
        duplicateProgress = nil
        duplicateSelected.removeAll()
        lastCleanResult = nil
        phase = .scanning
        statusMessage = "扫描重复文件中"
        scanProgress = 0
        let root = duplicateRoot
        duplicateTask = Task { [weak self] in
            let finder = DuplicateFinder()
            do {
                let result = try await finder.scan(folder: root) { progress in
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.duplicateProgress = progress
                        if let fraction = progress.fractionCompleted { self.scanProgress = fraction }
                        self.currentPath = progress.currentURL?.path ?? ""
                    }
                }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.duplicateResult = result
                    self.duplicateScanning = false
                    self.phase = .idle
                    self.lastScanDate = Date()
                    self.statusMessage = "就绪 · 找到 \(result.groups.count) 组重复文件"
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.duplicateScanning = false
                    self.phase = .idle
                    self.duplicateError = error.localizedDescription
                    self.statusMessage = "扫描失败"
                }
            }
        }
    }

    // MARK: - 选中项与清理

    /// 当前页签下待清理的条目（用于状态栏计数与统一确认弹窗）。
    var selectedItems: [CleanableItem] {
        switch activeTab {
        case .junk:
            return junkResults.flatMap { $0.items.filter { $0.isSelected } }
        case .large:
            return largeFiles.filter { $0.isSelected }
        case .duplicate:
            guard let result = duplicateResult else { return [] }
            var sizes: [URL: Int64] = [:]
            for group in result.groups {
                for file in group.files { sizes[file.url] = file.size }
            }
            return duplicateSelected.map { url in
                CleanableItem(name: url.lastPathComponent, path: url.path,
                              size: sizes[url] ?? 0, category: .largeFiles,
                              isSelected: true, lastModified: nil)
            }
        default:
            return []
        }
    }

    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var canCleanSelection: Bool { phase == .idle && !selectedItems.isEmpty }

    func clearSelection() {
        switch activeTab {
        case .junk:
            for r in junkResults.indices {
                for i in junkResults[r].items.indices where !junkResults[r].items[i].selectOnlyByHand {
                    junkResults[r].items[i].isSelected = false
                }
            }
        case .large:
            for i in largeFiles.indices { largeFiles[i].isSelected = false }
        case .duplicate:
            duplicateSelected.removeAll()
        case .uninstall:
            checkedHigh.removeAll()
            checkedReview.removeAll()
        default:
            break
        }
    }

    func toggleJunkCategory(_ category: CleaningCategory, selected: Bool) {
        guard let r = junkResults.firstIndex(where: { $0.category == category }) else { return }
        for i in junkResults[r].items.indices where !junkResults[r].items[i].selectOnlyByHand {
            junkResults[r].items[i].isSelected = selected
        }
    }

    func setLargeFilesSelected(_ value: Bool) {
        for i in largeFiles.indices { largeFiles[i].isSelected = value }
    }

    func setJunkItemSelected(_ id: UUID, value: Bool) {
        for r in junkResults.indices {
            if let i = junkResults[r].items.firstIndex(where: { $0.id == id }) {
                junkResults[r].items[i].isSelected = value
                return
            }
        }
    }

    func setLargeFileSelected(_ id: UUID, value: Bool) {
        if let i = largeFiles.firstIndex(where: { $0.id == id }) {
            largeFiles[i].isSelected = value
        }
    }

    func cleanSelected(permanent: Set<String> = []) {
        guard canCleanSelection else { return }
        cleanTask?.cancel()
        cleanTask = Task { [weak self] in
            await self?.performClean(permanent: permanent)
        }
    }

    private func performClean(permanent: Set<String>) async {
        phase = .cleaning
        statusMessage = "清理中"
        scanProgress = 0
        lastCleanResult = nil
        let items = selectedItems
        if activeTab == .duplicate {
            await cleanDuplicates()
        } else {
            let result = await trash.clean(items, permanentPaths: permanent) { [weak self] progress in
                Task { @MainActor in self?.scanProgress = progress }
            }
            applyCleanResult(result)
        }
        phase = .idle
        scanProgress = 0
        if lastCleanResult != nil { statusMessage = "就绪 · 清理完成" }
    }

    private func applyCleanResult(_ result: TrashResult) {
        lastCleanResult = result
        junkResults = junkResults.map { r in
            var copy = r
            copy.items.removeAll { result.cleanedPaths.contains($0.path) }
            copy.totalSize = copy.items.reduce(0) { $0 + $1.size }
            return copy
        }
        largeFiles.removeAll { result.cleanedPaths.contains($0.path) }
    }

    private func cleanDuplicates() async {
        guard let result = duplicateResult else { return }
        let finder = DuplicateFinder()
        var trashed: [DuplicateFile] = []
        var failures: [DuplicateTrashFailure] = []
        for group in result.groups {
            if Task.isCancelled { break }
            let ids = duplicateSelected.filter { group.contains($0) }
            guard !ids.isEmpty, !ids.contains(group.keeper.url) else { continue }
            do {
                let report = try await finder.moveToTrash(group: group, selectedIDs: ids)
                trashed.append(contentsOf: report.trashedFiles)
                failures.append(contentsOf: report.failures)
            } catch {
                failures.append(DuplicateTrashFailure(url: group.keeper.url, message: error.localizedDescription))
            }
        }
        let trashedURLs = Set(trashed.map(\.url))
        var summary = TrashResult()
        summary.itemsCleaned = trashed.count
        summary.freedSpace = trashed.reduce(0) { $0 + $1.size }
        summary.errors = failures.map { "\($0.url.lastPathComponent): \($0.message)" }
        summary.cleanedPaths = Set(trashed.map { $0.url.path })
        summary.trashedPaths = summary.cleanedPaths
        lastCleanResult = summary
        duplicateSelected.subtract(trashedURLs)
        duplicateResult = prunedGroups(result, removing: trashedURLs)
    }

    private func prunedGroups(_ result: DuplicateScanResult, removing urls: Set<URL>) -> DuplicateScanResult {
        let groups = result.groups.compactMap { group -> DuplicateGroup? in
            let remaining = group.files.filter { !urls.contains($0.url) }
            return remaining.count >= 2 ? DuplicateGroup(digest: group.digest, files: remaining) : nil
        }
        return DuplicateScanResult(folder: result.folder, groups: groups,
                                   skippedFiles: result.skippedFiles,
                                   filesInspected: result.filesInspected,
                                   bytesHashed: result.bytesHashed)
    }

    // MARK: - 卸载

    func loadInstalledApps() {
        let fm = FileManager.default
        let roots = ["/Applications", NSHomeDirectory() + "/Applications"]
        var apps: [AppPathFinder.AppInfo] = []
        for root in roots {
            let urls = (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: root),
                                                    includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "app" {
                guard let dict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                      let bundleID = dict["CFBundleIdentifier"] as? String else { continue }
                let name = (dict["CFBundleDisplayName"] as? String)
                    ?? (dict["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(AppPathFinder.AppInfo(appName: name, bundleIdentifier: bundleID,
                                                  path: url, entitlements: nil, teamIdentifier: nil))
            }
        }
        installedApps = apps.sorted {
            $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    func selectApp(_ app: AppPathFinder.AppInfo) {
        selectedApp = app
        highConfidenceResiduals = []
        reviewResiduals = []
        checkedHigh = []
        checkedReview = []
        selectedAppSize = 0
        let url = app.path
        Task { [weak self] in
            let size = await Self.appBundleSize(url)
            guard let self, self.selectedApp?.path == url else { return }
            self.selectedAppSize = size
        }
    }

    func scanResiduals() {
        guard let app = selectedApp else { return }
        scanningResiduals = true
        statusMessage = "扫描残留中"
        let info = app
        Task.detached(priority: .utility) { [weak self] in
            let finder = AppPathFinder(appInfo: info)
            let found = finder.findPaths().filter { $0.path != info.path.path }
            let high = found.filter { OrphanSafetyPolicy.isSafeCandidate($0) }.sorted { $0.path < $1.path }
            let review = found.filter { !OrphanSafetyPolicy.isSafeCandidate($0) }.sorted { $0.path < $1.path }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.highConfidenceResiduals = high
                self.reviewResiduals = review
                // 默认零选中（design.md 安全规则 1）；高置信组可批量勾选，需核对组只能逐项勾选
                self.checkedHigh = []
                self.checkedReview = []
                self.scanningResiduals = false
                self.statusMessage = "就绪 · 发现 \(found.count) 项关联文件"
            }
        }
    }

    func uninstallSelectedApp() async {
        guard let app = selectedApp, phase == .idle else { return }
        phase = .cleaning
        statusMessage = "卸载中"
        scanProgress = 0
        lastCleanResult = nil
        let residualPaths = (Array(checkedHigh) + Array(checkedReview)).map(\.path)
        // 应用包先移入废纸篓，再清残留（设计图顺序）
        let (bundleOK, bundleError) = await trashApplicationBundle(app.path)
        let result = await trash.removeResiduals(residualPaths)
        var combined = result
        if bundleOK {
            combined.itemsCleaned += 1
            combined.freedSpace += selectedAppSize
            combined.cleanedPaths.insert(app.path.path)
        }
        if let bundleError { combined.errors.append(bundleError) }
        lastCleanResult = combined
        let removed = combined.cleanedPaths
        highConfidenceResiduals.removeAll { removed.contains($0.path) }
        reviewResiduals.removeAll { removed.contains($0.path) }
        checkedHigh.removeAll()
        checkedReview.removeAll()
        if bundleOK {
            installedApps.removeAll { $0.path == app.path }
            selectedApp = nil
            selectedAppSize = 0
        }
        phase = .idle
        statusMessage = "就绪 · 卸载完成"
    }

    private static func appBundleSize(_ url: URL) async -> Int64 {
        await Task.detached(priority: .utility) { () -> Int64 in
            let fm = FileManager.default
            var total: Int64 = 0
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { return 0 }
            for case let file as URL in enumerator {
                guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let size = values.totalFileAllocatedSize else { continue }
                total += Int64(size)
            }
            return total
        }.value
    }

    private func trashApplicationBundle(_ url: URL) async -> (Bool, String?) {
        await Task.detached(priority: .utility) { () -> (Bool, String?) in
            let fm = FileManager.default
            let path = url.standardizedFileURL.path
            let allowed = ["/Applications", NSHomeDirectory() + "/Applications"]
            guard allowed.contains(where: { path.hasPrefix($0 + "/") }) else {
                return (false, "应用不在允许卸载的目录：\(path)")
            }
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                return (false, "应用包是符号链接，已跳过")
            }
            do {
                var resulting: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resulting)
                return (true, nil)
            } catch {
                return (false, "应用包移入废纸篓失败：\(error.localizedDescription)")
            }
        }.value
    }

    // MARK: - 磁盘 / 概览

    func volumeName() -> String {
        (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? "启动磁盘"
    }

    func diskInfo() -> DiskInfo {
        var info = DiskInfo()
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return info }
        if let total = attrs[.systemSize] as? Int64 { info.totalSpace = total }
        if let free = attrs[.systemFreeSize] as? Int64 { info.freeSpace = free }
        info.usedSpace = info.totalSpace - info.freeSpace
        return info
    }

    func overviewSummary(for card: SystemToolOverviewCard) -> SystemToolOverviewSummary {
        switch card {
        case .systemJunk: return junkSummary(.systemJunk)
        case .userCache: return junkSummary(.userCache)
        case .trash: return junkSummary(.trashBins)
        case .devCaches:
            let categories: [CleaningCategory] = [.xcodeJunk, .brewCache, .nodeCache, .devToolCaches]
            let results = junkResults.filter { categories.contains($0.category) }
            return SystemToolOverviewSummary(
                scanned: !results.isEmpty,
                count: results.reduce(0) { $0 + $1.itemCount },
                size: results.reduce(0) { $0 + $1.totalSize })
        case .largeFiles:
            return SystemToolOverviewSummary(
                scanned: !largeFiles.isEmpty,
                count: largeFiles.count,
                size: largeFiles.reduce(0) { $0 + $1.size })
        case .duplicates:
            guard let result = duplicateResult else { return SystemToolOverviewSummary() }
            return SystemToolOverviewSummary(
                scanned: true, count: result.groups.count, size: result.reclaimableSize)
        }
    }

    private func junkSummary(_ category: CleaningCategory) -> SystemToolOverviewSummary {
        guard let result = junkResults.first(where: { $0.category == category }) else {
            return SystemToolOverviewSummary()
        }
        return SystemToolOverviewSummary(scanned: true, count: result.itemCount, size: result.totalSize)
    }

    // MARK: - 进程

    func setProcessMonitoring(_ active: Bool) { processMonitor.setActive(active) }
    var processMonitorObject: ProcessResourceMonitor { processMonitor }
}
