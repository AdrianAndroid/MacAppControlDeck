// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 移植适配自 Services/ScanEngine.swift，保留原版权声明与核心扫描算法。
// 适配说明：
//  - 只保留 systemJunk / userCache / trashBins / largeFiles / xcodeJunk /
//    brewCache / nodeCache / devToolCaches 八个分类的纯路径扫描。
//  - 删除 smartScan / purgeableSpace / aiApps / mailAttachments / docker /
//    rustTargets / nodeModules / universalBinaries / languageFiles / simulator
//    分支及其外部依赖（BrewProcessRunner、SimulatorRuntimeSupport、
//    UniversalBinaryScanner、LanguageFilesScanner）。
//  - brew/node 分类改为纯缓存路径扫描，不执行任何 brew/npm 命令。
//  - 沿用上游的安全过滤：符号链接跳过、SIP 保护跳过、路径标准化去重。

import Foundation

actor ScanEngine {
    private let fileManager = FileManager.default
    private let home: String
    /// 用户在设置页维护的排除路径（含子路径），每次扫描开始时读取一次。
    private var excludedPaths: Set<String> = []

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        home = homeDirectory.resolvingSymlinksInPath().path
    }

    // MARK: - Progress reporting

    private var onPath: (@Sendable (String) -> Void)?
    private var lastReport = Date.distantPast

    private func report(_ path: @autoclosure () -> String) {
        guard let onPath else { return }
        let now = Date()
        guard now.timeIntervalSince(lastReport) > 0.1 else { return }
        lastReport = now
        onPath(path())
    }

    // MARK: - Public API

    func scanCategory(
        _ category: CleaningCategory,
        onPath: (@Sendable (String) -> Void)? = nil
    ) async -> CategoryResult {
        self.onPath = onPath
        self.excludedPaths = Set(CleanupExclusions.paths().map { normalizePath($0) })
        defer { self.onPath = nil }
        switch category {
        case .systemJunk: return scanSystemJunk()
        case .userCache: return scanUserCache()
        case .trashBins: return scanTrash()
        case .largeFiles: return scanLargeFiles()
        case .xcodeJunk: return scanXcodeJunk()
        case .brewCache: return scanBrewCache()
        case .nodeCache: return scanNodeCache()
        case .devToolCaches: return scanDevToolCaches()
        }
    }

    func getDiskInfo() -> DiskInfo {
        var info = DiskInfo()
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? Int64 { info.totalSpace = total }
            if let free = attrs[.systemFreeSize] as? Int64 { info.freeSpace = free }
            info.usedSpace = info.totalSpace - info.freeSpace
            let rootURL = URL(fileURLWithPath: "/")
            let values = try rootURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey
            ])
            if let important = values.volumeAvailableCapacityForImportantUsage,
               let free = values.volumeAvailableCapacity {
                let purgeable = important - Int64(free)
                if purgeable > 10 * 1024 * 1024 { info.purgeableSpace = purgeable }
            }
        } catch {
            Logger.shared.log("Disk info unavailable: \(error.localizedDescription)", level: .warning)
        }
        return info
    }

    // MARK: - Scanners (pure filesystem paths)

    private func scanSystemJunk() -> CategoryResult {
        let systemPaths = [
            "/Library/Caches", "/Library/Logs", "/private/var/log",
            "\(home)/Library/Logs", "/tmp", "/private/var/tmp",
        ]
        let items = systemPaths.flatMap {
            scanDirectory(path: $0, category: .systemJunk)
        }
        return CategoryResult(category: .systemJunk, items: items, totalSize: items.totalSize)
    }

    private func scanUserCache() -> CategoryResult {
        let excluded = Set((
            DevToolCaches.absolutePaths(home: home)
            + ProviderPaths.deniedRoots(homeDirectory: URL(fileURLWithPath: home, isDirectory: true))
        ).map(normalizePath))

        var items = scanDirectory(
            path: "\(home)/Library/Caches", category: .userCache, excluding: excluded
        )

        let containerRoots = ["\(home)/Library/Containers", "\(home)/Library/Group Containers"]
        for root in containerRoots {
            guard let containers = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            let cacheSubpath = root.hasSuffix("Group Containers") ? "Library/Caches" : "Data/Library/Caches"
            for container in containers {
                let cachePath = (root as NSString)
                    .appendingPathComponent(container)
                    .appending("/" + cacheSubpath)
                let resolved = URL(fileURLWithPath: cachePath).resolvingSymlinksInPath().path
                guard normalizePath(resolved) == normalizePath(cachePath) else { continue }
                if let item = makeCleanupItem(
                    name: "\(container) (sandbox cache)", path: cachePath,
                    category: .userCache, minimumSize: 1024 * 1024
                ) { items.append(item) }
            }
        }

        items.append(contentsOf: scanDirectory(
            path: "\(home)/Library/HTTPStorages", category: .userCache, isSelected: false
        ))
        let unique = deduplicatedItems(items)
        return CategoryResult(category: .userCache, items: unique, totalSize: unique.totalSize)
    }

    private func scanTrash() -> CategoryResult {
        let items = scanDirectory(path: "\(home)/.Trash", category: .trashBins)
        return CategoryResult(category: .trashBins, items: items, totalSize: items.totalSize)
    }

    /// 大文件扫描根目录：与 SystemToolScanRoots 共享同一份定义，
    /// 保证「扫哪里」与「允许清哪里」永远一致，不出现扫出来却清不掉。
    private func largeFileRoots() -> [String] {
        SystemToolScanRoots.largeFileRoots(home: home)
    }

    private func scanLargeFiles() -> CategoryResult {
        let defaults = UserDefaults.standard
        let thresholdMB = defaults.object(forKey: "systemTool.cleaning.largeFileThreshold") as? Int ?? 100
        let oldMonths = defaults.object(forKey: "systemTool.cleaning.oldFileMonths") as? Int ?? 12
        let minSize = Int64(max(1, thresholdMB)) * 1024 * 1024
        let oldCutoff = Calendar.current.date(byAdding: .month, value: -max(1, oldMonths), to: Date())
            ?? Date.distantPast
        let excludedFolders = ((defaults.stringArray(forKey: "systemTool.cleaning.largeFileExcludedFolders") ?? [])
            + CleanupExclusions.paths())
            .map(normalizePath).filter { !$0.isEmpty }
        let skipHidden = defaults.object(forKey: "systemTool.cleaning.skipHiddenFiles") as? Bool ?? true

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if skipHidden { options.insert(.skipsHiddenFiles) }

        var items: [CleanableItem] = []
        for basePath in largeFileRoots() {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: options
            ) else { continue }
            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                if !excludedFolders.isEmpty {
                    let normalized = normalizePath(fileURL.path)
                    if excludedFolders.contains(where: { normalized == $0 || normalized.hasPrefix($0 + "/") }) {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                report(fileURL.path)
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      let isFile = values.isRegularFile, isFile,
                      let fileSize = values.fileSize else { continue }
                let size = Int64(fileSize)
                let modDate = values.contentModificationDate
                if size > minSize || (modDate != nil && modDate! < oldCutoff && size > 10 * 1024 * 1024) {
                    items.append(CleanableItem(
                        name: fileURL.lastPathComponent, path: fileURL.path, size: size,
                        category: .largeFiles, isSelected: false, lastModified: modDate
                    ))
                }
            }
        }
        items.sort { $0.size > $1.size }
        return CategoryResult(category: .largeFiles, items: items, totalSize: items.totalSize)
    }

    private func scanXcodeJunk() -> CategoryResult {
        let paths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            "\(home)/Library/Developer/CoreSimulator/Caches",
            "\(home)/Library/Caches/com.apple.dt.Xcode",
        ]
        let items = paths.compactMap {
            makeCleanupItem(name: ($0 as NSString).lastPathComponent, path: $0, category: .xcodeJunk)
        }
        return CategoryResult(category: .xcodeJunk, items: items, totalSize: items.totalSize)
    }

    private func scanBrewCache() -> CategoryResult {
        let paths = [
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Caches", "/usr/local/Caches",
            "/private/var/folders",  // Homebrew downloads land in temp; guarded by macOS itself
        ].filter { $0 != "/private/var/folders" } // 不扫描系统临时根，避免误伤
        let items = paths.compactMap {
            makeCleanupItem(name: ($0 as NSString).lastPathComponent, path: $0, category: .brewCache)
        }
        return CategoryResult(category: .brewCache, items: items, totalSize: items.totalSize)
    }

    private func scanNodeCache() -> CategoryResult {
        let paths = [
            "\(home)/.npm/_cacache",
            "\(home)/Library/Caches/Yarn",
            "\(home)/Library/Caches/pnpm",
            "\(home)/.cache/yarn",
            "\(home)/.local/share/pnpm/store",
        ]
        let items = paths.compactMap {
            makeCleanupItem(name: ($0 as NSString).lastPathComponent, path: $0, category: .nodeCache)
        }
        return CategoryResult(category: .nodeCache, items: items, totalSize: items.totalSize)
    }

    private func scanDevToolCaches() -> CategoryResult {
        var items: [CleanableItem] = []
        for root in DevToolCaches.roots {
            let path = root.path(home: home)
            if let item = makeCleanupItem(name: root.nameKey, path: path, category: .devToolCaches) {
                var adjusted = item
                adjusted.isSelected = root.selectedByDefault
                items.append(adjusted)
            }
        }
        return CategoryResult(category: .devToolCaches, items: items, totalSize: items.totalSize)
    }

    // MARK: - Helpers

    private func scanDirectory(
        path: String,
        category: CleaningCategory,
        isSelected: Bool = true,
        excluding excludedPaths: Set<String> = []
    ) -> [CleanableItem] {
        var items: [CleanableItem] = []
        guard fileManager.fileExists(atPath: path), fileManager.isReadableFile(atPath: path) else { return [] }
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                if Task.isCancelled { break }
                let fullPath = (path as NSString).appendingPathComponent(item)
                report(fullPath)
                let standardized = normalizePath(fullPath)
                if excludedPaths.contains(standardized)
                    || self.excludedPaths.contains(standardized)
                    || self.excludedPaths.contains(where: { standardized.hasPrefix($0 + "/") }) { continue }

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let fileType = attrs[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                    continue
                }
                if FileProtection.isProtectedFromDeletion(path: fullPath) { continue }

                if isDir.boolValue {
                    let size = directorySize(path: fullPath)
                    if size > 1024 {
                        items.append(CleanableItem(
                            name: item, path: fullPath, size: size, category: category,
                            isSelected: isSelected, lastModified: fileModDate(path: fullPath)
                        ))
                    }
                } else if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                          let size = attrs[.size] as? Int64, size > 1024 {
                    items.append(CleanableItem(
                        name: item, path: fullPath, size: size, category: category,
                        isSelected: isSelected, lastModified: attrs[.modificationDate] as? Date
                    ))
                }
            }
        } catch {
            Logger.shared.log("Cannot enumerate \(path): \(error.localizedDescription)", level: .warning)
        }
        return items
    }

    private func makeCleanupItem(
        name: String, path: String, category: CleaningCategory,
        isSelected: Bool = true, minimumSize: Int64 = 1024
    ) -> CleanableItem? {
        report(path)
        let standardized = normalizePath(path)
        if excludedPaths.contains(standardized)
            || excludedPaths.contains(where: { standardized.hasPrefix($0 + "/") }) { return nil }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              fileManager.isReadableFile(atPath: path) else { return nil }
        if isDirectory.boolValue {
            let size = directorySize(path: path)
            guard size > minimumSize else { return nil }
            return CleanableItem(name: name, path: path, size: size, category: category,
                                 isSelected: isSelected, lastModified: fileModDate(path: path))
        }
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > minimumSize else { return nil }
        return CleanableItem(name: name, path: path, size: size, category: category,
                             isSelected: isSelected, lastModified: attrs[.modificationDate] as? Date)
    }

    private func deduplicatedItems(_ items: [CleanableItem]) -> [CleanableItem] {
        var seen: Set<String> = []
        return items.filter { seen.insert(normalizePath($0.path)).inserted }
    }

    private func normalizePath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private func directorySize(path: String) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            report(fileURL.path)
            guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]),
                  let isFile = values.isRegularFile, isFile else { continue }
            if let size = values.totalFileAllocatedSize ?? values.fileSize { total += Int64(size) }
        }
        return total
    }

    private func fileModDate(path: String) -> Date? {
        try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
}

private extension Array where Element == CleanableItem {
    var totalSize: Int64 { reduce(0) { $0 + $1.size } }
}
