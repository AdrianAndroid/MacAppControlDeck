// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 移植适配自 Logic/Scanning/AppPathFinder.swift，保留核心残留匹配启发式。
// 适配说明：
//  - 内联 Locations.appSearch 路径表（不再依赖 ObservableObject 的 Locations）。
//  - 用 OrphanSafetyPolicy / ProviderPaths 做通用安全过滤，替换上游
//    Conditions.swift 里 appConditions / skipConditions / skipDeepSearch
//    特定应用规则表（第一版不需要这些逐 app 覆盖）。
//  - 保留 bundle ID + app 名 + 路径名 + 容器元数据的分级匹配。

import Foundation

final class AppPathFinder {
    struct AppInfo {
        let appName: String
        let bundleIdentifier: String
        let path: URL
        let entitlements: [String]?
        let teamIdentifier: String?
    }

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    /// 标准 macOS Library 子目录：depth=2 命中时用于判断是否上移到 vendor 父目录。
    private static let standardLibrarySubdirectories: Set<String> = [
        "Application Scripts", "Application Support", "Caches",
        "Containers", "Group Containers", "HTTPStorages",
        "Internet Plug-Ins", "LaunchAgents", "LaunchDaemons",
        "Logs", "Preferences", "PreferencePanes",
        "PrivilegedHelperTools", "Saved Application State",
        "Services", "WebKit", "Extensions", "Frameworks",
    ]

    /// 从上游 Locations.swift 内联的应用残留搜索路径（已剔除裸 $HOME）。
    private static func appSearchPaths() -> [String] {
        let h = home
        return [
            "\(h)/.config", "\(h)/Documents", "\(h)/Desktop", "\(h)/Applications",
            "\(h)/Library", "\(h)/Library/Application Scripts",
            "\(h)/Library/Application Support", "\(h)/Library/Application Support/CrashReporter",
            "\(h)/Library/Containers", "\(h)/Library/Caches",
            "\(h)/Library/Group Containers", "\(h)/Library/HTTPStorages",
            "\(h)/Library/Internet Plug-Ins", "\(h)/Library/LaunchAgents",
            "\(h)/Library/Logs", "\(h)/Library/Logs/DiagnosticReports",
            "\(h)/Library/Preferences", "\(h)/Library/PreferencePanes",
            "\(h)/Library/Preferences/ByHost", "\(h)/Library/Saved Application State",
            "\(h)/Library/Services", "\(h)/Library/WebKit",
            "/Applications", "/Users/Shared", "/Users/Shared/Library/Application Support",
            "/Library", "/Library/Application Support", "/Library/Application Support/CrashReporter",
            "/Library/Caches", "/Library/Extensions", "/Library/Internet Plug-Ins",
            "/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/Logs",
            "/Library/Logs/DiagnosticReports", "/Library/Preferences",
            "/Library/PrivilegedHelperTools", "/private/var/db/receipts", "/private/tmp",
        ]
    }

    private let appInfo: AppInfo
    private var collectionSet: Set<URL> = []
    private let collectionQueue = DispatchQueue(label: "com.macappcontroldeck.puremac.pathfinder")

    private let normalizedBundleID: String
    private let bundleLastTwo: String
    private let normalizedAppName: String
    private let appNameLettersOnly: String
    private let pathComponentName: String
    private let companyName: String?
    private let baseBundleID: String?
    private let strippedAppName: String?
    private let normalizedEntitlements: [String]
    private let normalizedTeamID: String?

    init(appInfo: AppInfo) {
        self.appInfo = appInfo
        self.normalizedBundleID = appInfo.bundleIdentifier.normalizedForMatching()
        self.bundleLastTwo = appInfo.bundleIdentifier.bundleLastTwoComponents
        self.normalizedAppName = appInfo.appName.normalizedForMatching()
        self.appNameLettersOnly = appInfo.appName.lettersOnly
        self.pathComponentName = appInfo.path.lastPathComponent
            .replacingOccurrences(of: ".app", with: "").normalizedForMatching()
        self.companyName = appInfo.bundleIdentifier.bundleCompanyName
        self.baseBundleID = appInfo.bundleIdentifier.baseBundleIdentifier?.normalizedForMatching()
        let stripped = appInfo.appName.strippingTrailingVersion().normalizedForMatching()
        self.strippedAppName = (stripped != normalizedAppName && !stripped.isEmpty) ? stripped : nil
        self.normalizedEntitlements = appInfo.entitlements?.compactMap {
            let n = $0.normalizedForMatching()
            return n.isEmpty ? nil : n
        } ?? []
        self.normalizedTeamID = appInfo.teamIdentifier?.normalizedForMatching()
    }

    func findPaths() -> Set<URL> {
        collectionSet.insert(appInfo.path)
        for location in Self.appSearchPaths() {
            let isLibRoot = location == "\(Self.home)/Library" || location == "/Library"
            processLocation(location, currentDepth: 0, maxDepth: isLibRoot ? 2 : 1, isLibraryRootSearch: isLibRoot)
        }
        collectionSet.formUnion(discoverContainers())
        return filterSubpaths(collectionSet)
    }

    private static let minMatchTokenLength = 5

    private func processLocation(_ location: String, currentDepth: Int, maxDepth: Int, isLibraryRootSearch: Bool) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: location) else { return }
        var localResults: [URL] = []
        var subdirs: [URL] = []

        for item in contents {
            if Task.isCancelled { break }
            let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
            let normalizedName: String = (itemURL.hasDirectoryPath || itemURL.pathExtension.isEmpty)
                ? item.normalizedForMatching()
                : (item as NSString).deletingPathExtension.normalizedForMatching()

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { continue }
            if shouldSkip(itemURL) { continue }

            if matchesApp(normalizedName: normalizedName) {
                let toAdd: URL
                if isLibraryRootSearch && currentDepth == 2 {
                    let parent = itemURL.deletingLastPathComponent()
                    toAdd = Self.standardLibrarySubdirectories.contains(parent.lastPathComponent) ? itemURL : parent
                } else {
                    toAdd = itemURL
                }
                localResults.append(toAdd)
            }
            if isDir.boolValue && currentDepth < maxDepth { subdirs.append(itemURL) }
        }
        collectionQueue.sync { collectionSet.formUnion(localResults) }
        for subdir in subdirs {
            processLocation(subdir.path, currentDepth: currentDepth + 1, maxDepth: maxDepth, isLibraryRootSearch: isLibraryRootSearch)
        }
    }

    private func matchesApp(normalizedName: String) -> Bool {
        for entitlement in normalizedEntitlements where normalizedName.contains(entitlement) { return true }

        let fullBundleMatch = normalizedName.contains(normalizedBundleID)
        let minLen = Self.minMatchTokenLength
        let appNameMatch = normalizedAppName.count >= minLen && normalizedName.contains(normalizedAppName)
        let pathMatch = pathComponentName.count >= minLen && normalizedName.contains(pathComponentName)
        let lettersMatch = appNameLettersOnly.count >= minLen && normalizedName.contains(appNameLettersOnly)
        if (normalizedBundleID.count >= 5 && fullBundleMatch) || appNameMatch || pathMatch || lettersMatch { return true }

        if bundleLastTwo.count >= minLen, normalizedName.contains(bundleLastTwo) { return true }
        if let base = baseBundleID, base.count >= minLen, normalizedName.contains(base) { return true }
        if let stripped = strippedAppName, stripped.count >= minLen, normalizedName.contains(stripped) { return true }
        if let company = companyName, company.count >= minLen, normalizedName.contains(company) { return true }
        if let teamID = normalizedTeamID, teamID.count >= minLen, normalizedName.contains(teamID) { return true }
        return false
    }

    private func shouldSkip(_ url: URL) -> Bool {
        if collectionQueue.sync(execute: { collectionSet.contains(url) }) { return true }
        if ProviderPaths.isProviderOwned(url.path) { return true }
        if url.path.contains("/.Trash") { return true }
        return false
    }

    private func discoverContainers() -> [URL] {
        var containers: [URL] = []
        guard let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Containers") else { return containers }
        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: containersPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return containers }
        for dir in dirs {
            let name = dir.lastPathComponent
            if name.count == 36 && name.contains("-") {
                let meta = dir.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                if let plist = NSDictionary(contentsOf: meta),
                   let bundleID = plist["MCMMetadataIdentifier"] as? String,
                   bundleID == appInfo.bundleIdentifier {
                    containers.append(dir)
                }
            }
            if normalizedBundleID.count >= 5, name.normalizedForMatching() == normalizedBundleID {
                containers.append(dir)
            }
        }
        return containers
    }

    private func filterSubpaths(_ urls: Set<URL>) -> Set<URL> {
        let sorted = urls.map { $0.standardizedFileURL }.sorted { $0.path < $1.path }
        var filtered: [URL] = []
        for url in sorted {
            filtered.removeAll { $0.path.hasPrefix(url.path + "/") }
            if !filtered.contains(where: { url.path.hasPrefix($0.path + "/") }) { filtered.append(url) }
        }
        if filtered.count == 1, let first = filtered.first, first.path.contains(".Trash") { return [] }
        return Set(filtered)
    }
}
