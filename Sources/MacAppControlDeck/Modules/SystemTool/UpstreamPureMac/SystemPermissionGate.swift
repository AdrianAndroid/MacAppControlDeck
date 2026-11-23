// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 只读 FDA 检测逻辑参考自 Services/FullDiskAccessManager.swift，保留原版权声明。
// 适配：只保留「检测是否已获得完全磁盘访问」+「打开系统设置对应面板」，
// 不移植引导页/演示视图/自己的跳转 UI。

import Foundation
import AppKit

enum SystemPermissionGate {
    /// 通过尝试列举受 FDA 保护的目录来判断是否已授权（只读，无副作用）。
    static func hasFullDiskAccess() -> Bool {
        let probes = [
            "\(NSHomeDirectory())/Library/Containers/com.apple.Safari",
            "\(NSHomeDirectory())/Library/Application Support/com.apple.TCC",
            "\(NSHomeDirectory())/Library/Mail",
            "/Library/Application Support/com.apple.TCC",
        ]
        for path in probes {
            if FileManager.default.fileExists(atPath: path) {
                if (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil {
                    return true
                }
                return false
            }
        }
        // 没有任何受保护目录存在（罕见配置）：保守地认为未授权。
        return false
    }

    /// 打开系统设置的「完全磁盘访问」面板。
    static func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
