// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 核心删除路径提取适配自 Services/CleaningEngine.swift（约 150 行裁剪重写）。
// 安全契约（比上游更保守）：
//  - 默认一律 FileManager.trashItem 移入废纸篓，可恢复；
//  - 仅当 trashItem 失败且调用方显式允许永久删除时才 removeItem；
//  - 删除前符号链接检查 + 解析后二次校验，防止 TOCTOU 路径逃逸；
//  - SIP/immutable 保护路径跳过并计数，不产生错误提示；
//  - 排除路径、允许根范围校验；不引入管理员提权、二进制瘦身等逻辑。

import Foundation

struct TrashResult {
    var freedSpace: Int64 = 0
    var itemsCleaned: Int = 0
    var errors: [String] = []
    var trashedPaths: Set<String> = []       // 废纸篓里的目标路径
    var cleanedPaths: Set<String> = []       // 被清理的原始路径（供 UI 移除行）
    var skippedPaths: Set<String> = []
    var protectedPaths: Set<String> = []
    var permanentlyRemoved: Set<String> = []

    var skippedProtected: Int { protectedPaths.count }
}

actor SystemTrashService {
    private let fileManager = FileManager.default
    private let home: String

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        home = homeDirectory.resolvingSymlinksInPath().path
    }

    /// 清理选中项。permanentPaths 中列出的路径才允许永久删除（需 UI 单独二次确认）。
    func clean(
        _ items: [CleanableItem],
        permanentPaths: Set<String> = [],
        progress: (@Sendable (Double) -> Void)? = nil
    ) async -> TrashResult {
        var result = TrashResult()
        let exclusions = CleanupExclusions.paths()
        let total = max(1, items.count)

        for (index, item) in items.enumerated() {
            defer { progress?(Double(index + 1) / Double(total)) }
            if Task.isCancelled { break }

            if CleanupExclusions.excludes(item.path, paths: exclusions) {
                result.skippedPaths.insert(item.path)
                continue
            }
            guard passesSafetyCheck(item.path) else {
                result.skippedPaths.insert(item.path)
                Logger.shared.log("Skipped unsafe path: \(item.path)", level: .warning)
                continue
            }
            if FileProtection.isProtectedFromDeletion(path: item.path) {
                result.protectedPaths.insert(item.path)
                continue
            }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir) else {
                result.skippedPaths.insert(item.path)
                continue
            }

            do {
                let url = URL(fileURLWithPath: item.path)
                let permanent = permanentPaths.contains(item.path)
                if permanent {
                    // 永久删除：先再校验一次解析路径未变
                    let resolved = url.resolvingSymlinksInPath().path
                    guard resolved == (item.path as NSString).standardizingPath,
                          !hasUnexpectedSymlink(in: item.path) else {
                        result.errors.append("路径校验失败，已跳过：\(item.path)")
                        continue
                    }
                    try fileManager.removeItem(at: url)
                    result.permanentlyRemoved.insert(item.path)
                } else {
                    var resulting: NSURL?
                    try fileManager.trashItem(at: url, resultingItemURL: &resulting)
                    if let trashed = resulting?.path { result.trashedPaths.insert(trashed) }
                }
                result.freedSpace += item.size
                result.itemsCleaned += 1
                result.cleanedPaths.insert(item.path)
            } catch {
                result.errors.append("\(item.path): \(error.localizedDescription)")
                Logger.shared.log("Clean failed \(item.path): \(error.localizedDescription)", level: .error)
            }
        }
        return result
    }

    /// 卸载应用后清理残留目录：同样废纸篓优先。
    /// 残留可能位于 ~/Documents 等用户目录（"需人工核对"组），这些是用户逐项勾选确认过的，
    /// 因此不走 clean() 那条只约束自动扫描缓存项的 allowedRoots，
    /// 但仍限定在「用户主目录 / /Library 范围内 + 非高风险目录 + 非符号链接 + 非保护路径」。
    func removeResiduals(_ paths: [String]) async -> TrashResult {
        var result = TrashResult()
        let exclusions = CleanupExclusions.paths()
        for path in paths {
            if Task.isCancelled { break }
            if CleanupExclusions.excludes(path, paths: exclusions) {
                result.skippedPaths.insert(path)
                continue
            }
            let standardized = (path as NSString).standardizingPath
            guard isAllowedResidualRoot(standardized) else {
                result.skippedPaths.insert(path)
                continue
            }
            let resolved = URL(fileURLWithPath: standardized).resolvingSymlinksInPath().path
            guard resolved == standardized, !hasUnexpectedSymlink(in: standardized) else {
                result.skippedPaths.insert(path)
                continue
            }
            guard !FileProtection.isProtectedFromDeletion(path: standardized) else {
                result.protectedPaths.insert(path)
                continue
            }
            guard fileManager.fileExists(atPath: standardized) else {
                result.skippedPaths.insert(path)
                continue
            }
            do {
                var resulting: NSURL?
                try fileManager.trashItem(at: URL(fileURLWithPath: standardized), resultingItemURL: &resulting)
                if let trashed = resulting?.path { result.trashedPaths.insert(trashed) }
                result.cleanedPaths.insert(path)
                result.itemsCleaned += 1
            } catch {
                result.errors.append("\(path): \(error.localizedDescription)")
                Logger.shared.log("Residual trash failed \(path): \(error.localizedDescription)", level: .error)
            }
        }
        return result
    }

    /// 残留只允许落在用户主目录或 /Library 下，并排除与应用残留无关的高风险点目录。
    private func isAllowedResidualRoot(_ path: String) -> Bool {
        let lower = path.lowercased()
        let homeLower = home.lowercased()
        guard lower.hasPrefix(homeLower + "/") || lower.hasPrefix("/library/") else { return false }
        let risky = [
            "\(homeLower)/library/keychains", "\(homeLower)/library/cookies",
            "\(homeLower)/library/credentials", "\(homeLower)/library/containers/com.apple",
            "\(homeLower)/library/application support/com.apple",
            "\(homeLower)/library/preferences/com.apple",
            "\(homeLower)/.ssh", "\(homeLower)/.gnupg", "\(homeLower)/.aws",
            "\(homeLower)/.config", "\(homeLower)/.local/share",
            "/library/keychains", "/library/security",
        ]
        return !risky.contains { lower.hasPrefix($0) }
    }

    // MARK: - Safety

    /// 路径必须在允许的根范围内（用户主目录下的易失数据目录 + 系统缓存/日志 + 废纸篓），
    /// 且不含组件级符号链接。拒绝家目录敏感点、云同步状态、应用残留白名单之外的一切。
    private func passesSafetyCheck(_ path: String) -> Bool {
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { return false }
        let standardized = (path as NSString).standardizingPath
        let resolved = URL(fileURLWithPath: standardized).resolvingSymlinksInPath().path
        guard resolved == standardized else { return false }

        let allowedRoots = OrphanSafetyPolicy.allowedRoots + [
            "\(home)/Library/Caches", "\(home)/Library/Logs", "\(home)/.Trash",
        ]
        let inAllowed = allowedRoots.contains { root in
            let r = root.lowercased() + "/"
            return standardized.lowercased().hasPrefix(r)
        }
        guard inAllowed else { return false }
        if ProviderPaths.isProviderOwned(standardized) { return false }
        if hasUnexpectedSymlink(in: standardized) { return false }
        return true
    }

    /// 检查 path 的任一祖先组件（除 /tmp、/var 允许外）是否为符号链接。
    private func hasUnexpectedSymlink(in path: String) -> Bool {
        var url = URL(fileURLWithPath: path).standardizedFileURL
        while url.path != "/" {
            let current = url.path
            let type = (try? fileManager.attributesOfItem(atPath: current)[.type]) as? FileAttributeType
            if type == .typeSymbolicLink, current != "/tmp", current != "/var" { return true }
            let parent = url.deletingLastPathComponent()
            if parent.path == current { break }
            url = parent
        }
        return false
    }
}
