// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 移植自 Logic/Utilities/OrphanSafetyPolicy.swift，保留原版权声明。
// 适配：内联上游 Conditions.swift 中的 highRiskHomeDotPaths 常量，
// 避免引入整个扫描子系统。

import Foundation

enum OrphanSafetyPolicy {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    // Conservative allowlist: only volatile data directories.
    static let allowedRoots: [String] = [
        "\(home)/Library/Caches",
        "\(home)/Library/Logs",
        "\(home)/Library/Saved Application State",
        "\(home)/Library/HTTPStorages",
        "\(home)/Library/WebKit",
        "\(home)/Library/Application Support/CrashReporter",
        "/Library/Caches",
        "/Library/Logs",
    ]

    private static let blockedFragments: [String] = [
        "/Library/Preferences",
        "/Library/PreferencePanes",
        "/Library/Containers",
        "/Library/Group Containers",
        "/Library/Application Scripts",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/Library/PrivilegedHelperTools",
        "/Library/Keychains",
        "/Library/Mail",
        "/Library/Safari",
        "/Library/Messages",
        "/Library/Calendars",
        "/Library/Accounts",
        "/Library/Mobile Documents",
        "/Library/CloudStorage",
    ]

    static func isSafeCandidate(_ url: URL) -> Bool {
        let path = normalizedPath(url)
        let lowerPath = path.lowercased()

        // Belt-and-suspenders: reject any high-risk home dotpath.
        for root in highRiskHomeDotPaths {
            if path == root || path.hasPrefix(root + "/") {
                return false
            }
        }

        // Require the match to land STRICTLY inside the allowed root.
        guard allowedRoots.contains(where: { root in
            let rootWithSlash = root.lowercased() + "/"
            return lowerPath.hasPrefix(rootWithSlash)
        }) else {
            return false
        }

        if blockedFragments.contains(where: { lowerPath.contains($0.lowercased()) }) {
            return false
        }

        let name = url.lastPathComponent.lowercased()
        if name.hasPrefix("com.apple.") || name == ".globalpreferences.plist" {
            return false
        }

        return true
    }

    private static func normalizedPath(_ url: URL) -> String {
        let standardized = url.standardizedFileURL
        return standardized.resolvingSymlinksInPath().path
    }
}

// 内联自上游 Logic/Scanning/Conditions.swift：主目录下不得作为应用残留匹配的敏感路径。
private let highRiskHomeDotPaths: [String] = [
    "\(NSHomeDirectory())/.claude",
    "\(NSHomeDirectory())/.ssh",
    "\(NSHomeDirectory())/.aws",
    "\(NSHomeDirectory())/.gnupg",
    "\(NSHomeDirectory())/.gpg",
    "\(NSHomeDirectory())/.kube",
    "\(NSHomeDirectory())/.docker",
    "\(NSHomeDirectory())/.config",
    "\(NSHomeDirectory())/.git",
    "\(NSHomeDirectory())/.gitconfig",
    "\(NSHomeDirectory())/.git-credentials",
    "\(NSHomeDirectory())/.netrc",
    "\(NSHomeDirectory())/.npmrc",
    "\(NSHomeDirectory())/.yarnrc",
    "\(NSHomeDirectory())/.pnpmrc",
    "\(NSHomeDirectory())/.pip",
    "\(NSHomeDirectory())/.pypirc",
    "\(NSHomeDirectory())/.rbenv",
    "\(NSHomeDirectory())/.pyenv",
    "\(NSHomeDirectory())/.nvm",
    "\(NSHomeDirectory())/.cargo",
    "\(NSHomeDirectory())/.rustup",
    "\(NSHomeDirectory())/.gem",
    "\(NSHomeDirectory())/.local",
    "\(NSHomeDirectory())/.password-store",
    "\(NSHomeDirectory())/.mozilla",
    "\(NSHomeDirectory())/.wine",
    "\(NSHomeDirectory())/.vscode",
    "\(NSHomeDirectory())/.vim",
    "\(NSHomeDirectory())/.viminfo",
    "\(NSHomeDirectory())/.zshrc",
    "\(NSHomeDirectory())/.zsh_history",
    "\(NSHomeDirectory())/.bash_history",
    "\(NSHomeDirectory())/.bashrc",
    "\(NSHomeDirectory())/.bash_profile",
    "\(NSHomeDirectory())/.profile",
]
