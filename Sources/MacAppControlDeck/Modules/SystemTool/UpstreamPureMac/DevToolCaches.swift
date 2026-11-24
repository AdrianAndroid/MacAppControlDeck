// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 移植自 Logic/Utilities/DevToolCaches.swift，保留原版权声明。
// 适配：只保留 Root 定义与路径表（供扫描用）；移除 Removal 命令执行
// (uv/go clean) 与 DevToolCacheEnvironment 的 ps 进程探测——本模块第一版
// 统一走「移废纸篓」，不执行任何外部清理命令。

import Foundation

enum DevToolCaches {
    struct Root: Equatable {
        let id: String
        let nameKey: String
        let relativePath: String
        var selectedByDefault = true

        func path(home: String) -> String {
            (home as NSString).appendingPathComponent(relativePath)
        }
    }

    // Order matches the scan order shown in the UI.
    static let roots: [Root] = [
        Root(id: "bun", nameKey: "Bun cache", relativePath: ".bun/install/cache"),
        Root(id: "uv-xdg", nameKey: "uv cache", relativePath: ".cache/uv"),
        Root(id: "uv-library", nameKey: "uv cache", relativePath: "Library/Caches/uv"),
        Root(id: "pip-library", nameKey: "pip cache", relativePath: "Library/Caches/pip"),
        Root(id: "pip-xdg", nameKey: "pip cache", relativePath: ".cache/pip"),
        Root(id: "poetry-library", nameKey: "Poetry cache", relativePath: "Library/Caches/pypoetry"),
        Root(id: "poetry-xdg", nameKey: "Poetry cache", relativePath: ".cache/pypoetry"),
        Root(id: "cocoapods", nameKey: "CocoaPods cache", relativePath: "Library/Caches/CocoaPods"),
        Root(id: "swiftpm", nameKey: "Swift Package Manager cache", relativePath: "Library/Caches/org.swift.swiftpm"),
        Root(id: "gradle-caches", nameKey: "Gradle caches", relativePath: ".gradle/caches"),
        Root(id: "gradle-wrapper", nameKey: "Gradle wrapper distributions", relativePath: ".gradle/wrapper/dists"),
        Root(id: "cargo-registry-cache", nameKey: "Cargo registry cache", relativePath: ".cargo/registry/cache"),
        Root(id: "cargo-registry-index", nameKey: "Cargo registry index", relativePath: ".cargo/registry/index"),
        Root(id: "cargo-git-db", nameKey: "Cargo git database", relativePath: ".cargo/git/db"),
        Root(id: "cargo-git-checkouts", nameKey: "Cargo git checkouts", relativePath: ".cargo/git/checkouts"),
        Root(id: "go-build", nameKey: "Go build cache", relativePath: "Library/Caches/go-build"),
        Root(id: "go-modcache", nameKey: "Go module cache", relativePath: "go/pkg/mod"),
        Root(id: "deno-library", nameKey: "Deno cache", relativePath: "Library/Caches/deno"),
        Root(id: "deno-xdg", nameKey: "Deno cache", relativePath: ".cache/deno"),
        Root(id: "pub-hosted", nameKey: "Dart pub packages", relativePath: ".pub-cache/hosted"),
        Root(id: "pub-git", nameKey: "Dart pub git packages", relativePath: ".pub-cache/git"),
        Root(id: "playwright-library", nameKey: "Playwright browsers", relativePath: "Library/Caches/ms-playwright"),
        Root(id: "playwright-xdg", nameKey: "Playwright browsers", relativePath: ".cache/ms-playwright"),
        Root(id: "puppeteer", nameKey: "Puppeteer browsers", relativePath: ".cache/puppeteer"),
        Root(id: "node-gyp-library", nameKey: "node-gyp headers", relativePath: "Library/Caches/node-gyp"),
        Root(id: "node-gyp-xdg", nameKey: "node-gyp headers", relativePath: ".cache/node-gyp"),
        Root(id: "electron", nameKey: "Electron download cache", relativePath: "Library/Caches/electron"),
        Root(id: "electron-builder", nameKey: "Electron Builder cache", relativePath: "Library/Caches/electron-builder"),
        Root(id: "maven", nameKey: "Maven repository (may hold local installs)", relativePath: ".m2/repository", selectedByDefault: false),
        Root(id: "nuget-packages", nameKey: "NuGet packages (may hold local packages)", relativePath: ".nuget/packages", selectedByDefault: false),
        Root(id: "nuget-http", nameKey: "NuGet HTTP cache", relativePath: ".local/share/NuGet/http-cache", selectedByDefault: false),
    ]

    static func absolutePaths(home: String) -> [String] {
        roots.map { ($0.path(home: home) as NSString).standardizingPath }
    }

    static func contains(_ path: String, home: String) -> Bool {
        let normalized = (path as NSString).standardizingPath
        return absolutePaths(home: home).contains {
            normalized == $0 || normalized.hasPrefix($0 + "/")
        }
    }

    static func hasSymlinkBelowHome(_ path: String, home: String) -> Bool {
        let normalizedHome = (home as NSString).standardizingPath
        var current = (path as NSString).standardizingPath
        guard current.hasPrefix(normalizedHome + "/") else { return true }
        while current.count > normalizedHome.count {
            var info = stat()
            if lstat(current, &info) == 0, (info.st_mode & S_IFMT) == S_IFLNK { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }
}
