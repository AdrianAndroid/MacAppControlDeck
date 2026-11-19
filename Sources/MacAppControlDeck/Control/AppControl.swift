import AppKit
import ApplicationServices
import Foundation

struct AppActivationOutcome {
    var status: ActivateStatus
    var message: String
}

protocol AppControlling {
    func activate(bundleID: String) async -> AppActivationOutcome
}

final class AppControl: AppControlling {
    private let logURL: URL?
    private static var axPromptShown = false
    /// 记录"卡死态"的 bundleID → 时间，2 分钟内第二次点击则温和重启该应用。
    private let stateLock = NSLock()
    private var recentStuck: [String: Date] = [:]

    /// 弹出系统辅助功能授权对话框（每次运行最多一次）。
    static func promptAccessibilityIfNeeded() {
        guard !axPromptShown else { return }
        axPromptShown = true
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    init(logDirectory: URL? = nil) {
        let base = logDirectory ?? ConfigStore.defaultDirectory().appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        logURL = base.appendingPathComponent("activation.log")
    }

    func activate(bundleID: String) async -> AppActivationOutcome {
        guard let appURL = bestURL(forBundleID: bundleID) else {
            log("找不到应用 \(bundleID)")
            return AppActivationOutcome(status: .appNotFound,
                                        message: "应用未找到（可能已卸载或已删除）")
        }
        guard let running = Self.runningApp(bundleID) else {
            return await launch(appURL: appURL, bundleID: bundleID)
        }
        return await activate(running: running, appURL: appURL, bundleID: bundleID)
    }

    private func launch(appURL: URL, bundleID: String) async -> AppActivationOutcome {
        log("启动 \(bundleID)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            var running: NSRunningApplication?
            for _ in 0..<8 {
                running = Self.runningApp(bundleID)
                if running != nil { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard let running else {
                log("启动请求返回但未确认运行")
                let isSystemLauncher = bundleID.contains("launchpad")
                return AppActivationOutcome(
                    status: .unconfirmed,
                    message: isSystemLauncher
                        ? "已打开启动台（系统界面不会以常规应用形式出现，无法确认状态）"
                        : "已发送启动请求，未能确认运行（部分系统界面不显示为常规应用）")
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let outcome = await activate(running: running, appURL: appURL, bundleID: bundleID)
            let message = outcome.status == .activated ? "已启动并切到前台" : outcome.message
            return AppActivationOutcome(status: .launched, message: message)
        } catch {
            log("启动失败: \(error.localizedDescription)")
            return AppActivationOutcome(status: .activationFailed,
                                        message: "启动失败：\(error.localizedDescription)")
        }
    }

    private func activate(running: NSRunningApplication,
                          appURL: URL,
                          bundleID: String) async -> AppActivationOutcome {
        let policy = running.activationPolicy
        log("激活 \(bundleID) policy=\(policy.rawValue) hidden=\(running.isHidden)")

        // 策略零（首选）：通过辅助功能按下 Dock 里该应用的图标。
        // 与真人点击 Dock 完全等价——由 Dock 进程执行激活，
        // 天然支持"切换到窗口所在桌面空间"，连卡死态也能一次点开。
        if AXIsProcessTrusted() {
            let pressed = pressDockIcon(bundleID: bundleID, appURL: appURL)
            log("Dock 图标 AXPress -> \(pressed)")
            if pressed, let outcome = await evaluationIfSettled(bundleID, strategy: "Dock点击", wasHidden: running.isHidden, timeout: 8.0) {
                return outcome
            }
        }

        // 策略零点五：辅助功能已授权时，直接对目标窗口执行 AXRaise——
        // 这是唯一能可靠触发"切到窗口所在桌面空间并置于前台"的手段。
        if AXIsProcessTrusted() {
            let raised = await raiseWindow(pid: running.processIdentifier)
            log("AXRaise -> \(raised)")
            if raised, let outcome = await evaluationIfSettled(bundleID, strategy: "策略零", wasHidden: running.isHidden, timeout: 5.0) {
                return outcome
            }
        } else {
            log("辅助功能未授权，跳过 AXRaise")
        }

        // 策略一：macOS 14+ 的上下文激活
        let contextOK = await running.activate(from: NSRunningApplication.current)
        log("activate(from:) -> \(contextOK)")
        if let outcome = await evaluationIfSettled(bundleID, strategy: "策略一", wasHidden: running.isHidden) {
            return outcome
        }

        // 策略二：通过 LaunchServices 重新打开（与 open -a 同路径，常用于绕过聚焦保护）。
        // 注意：对 Java/JetBrains 类应用，后台进程的 LSOpen 只会标记“前台”而不切换空间。
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if (try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)) != nil {
            log("openApplication(激活) 已调用")
            if let outcome = await evaluationIfSettled(bundleID, strategy: "策略二", wasHidden: false) {
                return outcome
            }
        } else {
            log("openApplication(激活) 失败")
        }

        // 全部策略未成功：按真实原因反馈，不谎报
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isTargetFront = Self.isBundle(frontID, bundleID)
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知应用"
        log("未能切前台，当前前台=\(front) policy=\(policy.rawValue) 可见窗口=\(visibleWindowCount(bundleID)) 离屏窗口=\(offscreenWindowCount(bundleID))")
        if policy == .accessory || policy == .prohibited {
            return AppActivationOutcome(
                status: .unconfirmed,
                message: "已向该应用发送激活请求，但它是菜单栏/后台类应用，没有可确认的前台窗口（当前前台：\(front)）")
        }
        if !AXIsProcessTrusted() {
            Self.promptAccessibilityIfNeeded()
            return AppActivationOutcome(
                status: .unconfirmed,
                message: "系统未允许切到前台（当前前台：\(front)）。请到 系统设置 → 隐私与安全性 → 辅助功能 授权本程序并重启，之后可稳定切换")
        }
        if isTargetFront {
            return AppActivationOutcome(status: .activated, message: "已切换到前台")
        }
        return AppActivationOutcome(
            status: .unconfirmed,
            message: "系统未允许该应用切到前台（当前前台：\(front)）。可能受聚焦保护阻拦，请再点一次或在 Mac 上确认")
    }

    /// 成功判定：目标应用成为前台即算切换成功。
    /// 说明：Deck 进程内读到的 CGWindowList 与外部进程不一致（系统缓存问题），
    /// 因此窗口可见性只记入日志，不作为成功门槛。
    private func evaluationIfSettled(_ bundleID: String,
                                     strategy: String,
                                     wasHidden: Bool,
                                     timeout: TimeInterval = 3.0) async -> AppActivationOutcome? {
        let front = await waitForFront(bundleID, timeout: timeout)
        log("判定(\(strategy)) 前台=\(front) 可见窗口=\(visibleWindowCount(bundleID)) 离屏窗口=\(offscreenWindowCount(bundleID))")
        guard front else { return nil }
        return AppActivationOutcome(status: .activated,
                                    message: wasHidden ? "已取消隐藏并切到前台" : "已切换到前台")
    }


    /// 轮询等待：目标成为最前台应用。
    private func waitForFront(_ bundleID: String,
                              timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Self.isBundle(NSWorkspace.shared.frontmostApplication?.bundleIdentifier, bundleID) {
                return true
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return Self.isBundle(NSWorkspace.shared.frontmostApplication?.bundleIdentifier, bundleID)
    }

    /// 轮询等待：目标应用在当前屏幕/空间上出现可见窗口。
    private func waitForWindow(_ bundleID: String,
                               timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if visibleWindowCount(bundleID) > 0 { return true }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return visibleWindowCount(bundleID) > 0
    }

    /// 通过 CoreGraphics 统计目标应用在当前屏幕/空间上的可见窗口数量（无需辅助功能权限）。
    private func visibleWindowCount(_ bundleID: String) -> Int { windowCount(bundleID, onscreen: true) }

    /// 统计目标应用不在当前空间（或已最小化）的窗口数量，用于区分"无窗口"与"窗口在别处"。
    private func offscreenWindowCount(_ bundleID: String) -> Int { windowCount(bundleID, onscreen: false) }

    private func windowCount(_ bundleID: String, onscreen: Bool) -> Int {
        guard let pid = Self.runningApp(bundleID)?.processIdentifier else { return 0 }
        var options: CGWindowListOption = [.excludeDesktopElements]
        if onscreen { options.insert(.optionOnScreenOnly) }
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return list.filter { info in
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let onScreenNow = info[kCGWindowIsOnscreen as String] as? Bool ?? false
            let bounds = info[kCGWindowBounds as String] as? [String: Any]
            let width = bounds?["Width"] as? Double ?? 0
            let height = bounds?["Height"] as? Double ?? 0
            return ownerPID == pid && layer == 0 && onScreenNow != onscreen
                && width > 1 && height > 1
        }.count
    }

    /// 通过辅助功能"按下"Dock 中该应用的图标（等价于真人点击 Dock）。
    private func pressDockIcon(bundleID: String, appURL: URL) -> Bool {
        guard let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return false
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        var cfChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &cfChildren) == .success,
              let dockList = (cfChildren as? [AXUIElement])?.first else { return false }
        var cfItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockList, kAXChildrenAttribute as CFString, &cfItems) == .success,
              let items = cfItems as? [AXUIElement] else { return false }

        var names = [Self.runningApp(bundleID)?.localizedName,
                     appURL.deletingPathExtension().lastPathComponent,
                     Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String].compactMap { $0 }
        names = names.map(Self.normalizeName).filter { !$0.isEmpty }
        for item in items {
            var cfTitle: CFTypeRef?
            guard AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &cfTitle) == .success,
                  let title = cfTitle as? String else { continue }
            let normalized = Self.normalizeName(title)
            // "DevEco-Studio" vs 显示名 "DevEco Studio"：归一化后互相包含即可
            guard names.contains(where: { $0 == normalized || normalized.hasPrefix($0) || $0.hasPrefix(normalized) }) else { continue }
            if AXUIElementPerformAction(item, kAXPressAction as CFString) == .success {
                log("已按下 Dock 图标: \(title)")
                return true
            }
        }
        return false
    }

    static func normalizeName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// 用辅助功能 API 直接"提升"目标应用的窗口（会顺带取消最小化）。
    /// 对窗口在其他桌面空间的应用，AXRaise 会让系统直接切到该空间。
    private func raiseWindow(pid: pid_t) async -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var cfWindows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &cfWindows) == .success,
              let windows = cfWindows as? [AXUIElement] else { return false }
        for window in windows {
            var cfSize: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &cfSize) == .success,
                  cfSize != nil else { continue }
            let sizeValue = cfSize as! AXValue
            var size = CGSize.zero
            guard AXValueGetValue(sizeValue, .cgSize, &size), size.width > 100, size.height > 100 else { continue }
            var cfMinimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &cfMinimized) == .success,
               (cfMinimized as? Bool) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            if AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success {
                return true
            }
        }
        return false
    }

    static func isBundle(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    static func runningApp(_ bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { isBundle($0.bundleIdentifier, bundleID) }
    }

    private func bestURL(forBundleID bundleID: String) -> URL? {
        let urls = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID)
        if urls.isEmpty { return nil }
        return urls.min { priority($0) < priority($1) }
    }

    private func priority(_ url: URL) -> Int {
        let path = url.path
        if path.hasPrefix("/Applications/") { return 0 }
        if path.hasPrefix("/Applications/Utilities/") { return 1 }
        if path.hasPrefix("/System/Applications/") { return 2 }
        if path.hasPrefix(NSHomeDirectory()) { return 3 }
        return 4
    }

    private func log(_ line: String) {
        guard let logURL else { return }
        let text = "[\(Date().formatted(date: .numeric, time: .standard))] \(line)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        } else {
            try? Data(text.utf8).write(to: logURL)
        }
    }
}

enum AppEnumerator {
    static func installedApps() -> [InstalledApp] {
        var roots: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        roots += [URL(fileURLWithPath: "/Applications"),
                  URL(fileURLWithPath: "/System/Applications"),
                  home.appendingPathComponent("Applications")]
        var seen = Set<String>()
        var result: [InstalledApp] = []
        let fm = FileManager.default
        for root in roots {
            guard fm.fileExists(atPath: root.path) else { continue }
            let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil,
                                           options: [.skipsPackageDescendants])
            while let file = enumerator?.nextObject() as? URL {
                guard file.pathExtension == "app" else { continue }
                enumerator?.skipDescendants()
                guard let bundle = Bundle(url: file),
                      let bundleID = bundle.bundleIdentifier else { continue }
                guard !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? file.deletingPathExtension().lastPathComponent
                result.append(InstalledApp(name: name, bundleID: bundleID, path: file.path))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum IconCache {
    static func cachedIconURL(appPath: String, cacheURL: URL) -> URL? {
        if FileManager.default.fileExists(atPath: cacheURL.path) { return cacheURL }
        let nsImage = NSWorkspace.shared.icon(forFile: appPath)
        guard nsImage.size.width > 0 else { return nil }
        let size = NSSize(width: 128, height: 128)
        let target = NSImage(size: size)
        target.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: size),
                     from: NSRect(origin: .zero, size: nsImage.size),
                     operation: .copy, fraction: 1.0)
        target.unlockFocus()
        guard let tiff = target.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: cacheURL)
        return cacheURL
    }
}
