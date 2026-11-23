import Foundation

/// 扫描与清理共享的路径边界定义（本项目适配层，非上游移植代码）。
///
/// 背景：`ScanEngine` 决定「扫哪里」，`SystemTrashService` 决定「允许清哪里」。
/// 之前两处各自维护清单，清理侧误用了「卸载残留」的缓存白名单，导致大文件、
/// 开发缓存、Xcode 缓存、沙盒容器缓存等扫描结果在用户确认后被静默跳过。
/// 这里把允许范围收敛为一份定义，并要求两者同步，避免再次漂移。
///
/// 安全模型仍然是：默认零选中 → 用户逐项勾选 → 确认弹窗列出路径与大小 →
/// 优先移入废纸篓（可恢复）→ 永久删除需单独二次确认。本文件只划「允许范围」，
/// 不放松符号链接/TOCTOU、SIP 保护、排除路径、云同步状态的校验。
enum SystemToolScanRoots {
    static let largeFileRootsKey = "systemTool.cleaning.largeFileRoots"

    /// 大文件扫描根（设置页可配置，默认下载/文稿/桌面）。只接受绝对路径。
    static func largeFileRoots(home: String, defaults: UserDefaults = .standard) -> [String] {
        let configured = (defaults.stringArray(forKey: largeFileRootsKey) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.hasPrefix("/") }
        return configured.isEmpty
            ? ["\(home)/Downloads", "\(home)/Documents", "\(home)/Desktop"]
            : configured
    }

    /// 系统垃圾扫描根（与 ScanEngine.scanSystemJunk 一致）。
    /// 额外包含 /private/tmp，因为 /tmp 是其符号链接目标，解析后路径也需落在允许范围。
    static func systemJunkRoots(home: String) -> [String] {
        ["/Library/Caches", "/Library/Logs", "/private/var/log",
         "\(home)/Library/Logs", "/tmp", "/private/tmp", "/private/var/tmp"]
    }

    /// 用户缓存 / 沙盒缓存 / 废纸篓扫描根（与 ScanEngine.scanUserCache、scanTrash 一致）。
    static func userCacheRoots(home: String) -> [String] {
        ["\(home)/Library/Caches", "\(home)/Library/Containers",
         "\(home)/Library/Group Containers", "\(home)/Library/HTTPStorages",
         "\(home)/.Trash"]
    }

    /// 开发缓存 / Xcode / Homebrew / Node 缓存根（与 ScanEngine 对应分支一致）。
    static func developerCacheRoots(home: String) -> [String] {
        var roots: [String] = [
            "\(home)/Library/Developer",             // Xcode DerivedData/Archives/DeviceSupport/CoreSimulator
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Caches", "/usr/local/Caches",
            "\(home)/.npm", "\(home)/.cache", "\(home)/.local/share/pnpm",
        ]
        roots += DevToolCaches.absolutePaths(home: home)
        return roots
    }

    /// 允许清理的全部根：必须与 ScanEngine 实际会产出条目的根保持一致。
    static func cleanableRoots(home: String, defaults: UserDefaults = .standard) -> [String] {
        systemJunkRoots(home: home)
        + userCacheRoots(home: home)
        + developerCacheRoots(home: home)
        + largeFileRoots(home: home, defaults: defaults)
    }

    /// 任何情况下都不允许清理的路径（denylist，优先级高于 allowlist）。
    /// 逐项精确到子目录，避免误伤上面明确列入的开发缓存根（如 ~/.local/share/pnpm）。
    static func deniedRoots(home: String) -> [String] {
        [
            // 系统关键路径
            "/System", "/usr/bin", "/usr/sbin", "/usr/lib", "/usr/libexec", "/usr/share",
            "/bin", "/sbin", "/etc", "/var/db", "/private/var/db",
            "/Library/System", "/Library/Keychains", "/Library/Security",
            // 用户敏感数据
            "\(home)/Library/Keychains", "\(home)/Library/Cookies",
            "\(home)/Library/Credentials", "\(home)/Library/Preferences",
            "\(home)/Library/Accounts", "\(home)/Library/Mail",
            "\(home)/Library/Messages", "\(home)/Library/Safari",
            "\(home)/Library/Calendars", "\(home)/Library/LaunchAgents",
            "\(home)/Library/LaunchDaemons", "\(home)/Library/PrivilegedHelperTools",
            // 家目录敏感点目录 / 凭据
            "\(home)/.ssh", "\(home)/.gnupg", "\(home)/.gpg", "\(home)/.aws",
            "\(home)/.kube", "\(home)/.docker", "\(home)/.config", "\(home)/.git",
            "\(home)/.gitconfig", "\(home)/.git-credentials", "\(home)/.netrc",
            "\(home)/.password-store", "\(home)/.zshrc", "\(home)/.zsh_history",
            "\(home)/.bash_history", "\(home)/.bash_profile", "\(home)/.profile",
        ] + ProviderPaths.deniedRoots(homeDirectory: URL(fileURLWithPath: home))
    }

    static func isDenied(_ path: String, home: String) -> Bool {
        let lower = path.lowercased()
        return deniedRoots(home: home).contains { root in
            let r = root.lowercased()
            return lower == r || lower.hasPrefix(r + "/")
        }
    }

    /// 路径是否落在允许清理的根内（等于根本身或其子路径）。
    static func isWithinCleanableRoots(
        _ path: String, home: String, defaults: UserDefaults = .standard
    ) -> Bool {
        let lower = path.lowercased()
        return cleanableRoots(home: home, defaults: defaults).contains { root in
            let r = root.lowercased()
            return lower == r || lower.hasPrefix(r + "/")
        }
    }
}
