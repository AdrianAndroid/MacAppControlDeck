import SwiftUI

@main
struct DeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 设置窗口由 MenuBarController 自己管理（菜单栏应用没有主窗口）。
        // 这里保留一个 Settings 场景，用于 ⌘, 等系统默认行为。
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingSettingsTab: SettingsTab?
    private var launchFinished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏应用：不显示 Dock 图标，不开主窗口。
        NSApp.setActivationPolicy(.accessory)

        // 每个功能模块独立启停；remote 启动自己的 HTTP 服务，capture 只注册本机菜单。
        ModuleRegistry.shared.register(RemoteControlModule())
        ModuleRegistry.shared.register(CaptureModule.shared)
        ModuleRegistry.shared.register(SketchModule.shared)
        ModuleRegistry.shared.register(CalendarModule.shared)
        ModuleRegistry.shared.register(PetModule.shared)
        GlobalHotKeys.shared.install()
        MenuBarController.shared.install()
        // 自动升级最后启动：菜单栏先就绪，Sparkle 的后台检查弹窗才不会压在空状态上。
        UpdateController.shared.start()

        launchFinished = true
        if let tab = pendingSettingsTab {
            pendingSettingsTab = nil
            MenuBarController.shared.openSettings(tab: tab)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let tab = SettingsDeepLink.tab(from: url) else { continue }
            if launchFinished {
                MenuBarController.shared.openSettings(tab: tab)
            } else {
                pendingSettingsTab = tab
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出时只停服务，不改用户保存的模块开关。
        DeckState.shared.stop()
    }
}

enum SettingsDeepLink {
    static let scheme = "macappcontroldeck"

    static func tab(from url: URL) -> SettingsTab? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryTab = components?.queryItems?.first(where: { $0.name == "tab" })?.value,
           let tab = map(queryTab) {
            return tab
        }
        var segments: [String] = []
        if let host = url.host, !host.isEmpty { segments.append(host) }
        segments.append(contentsOf: url.path.split(separator: "/").map(String.init))
        for segment in segments {
            if let tab = map(segment) { return tab }
        }
        return nil
    }

    private static func map(_ raw: String) -> SettingsTab? {
        switch raw.lowercased() {
        case "general": return .general
        case "menu": return .menu
        case "hotkeys", "hotkey", "shortcut", "shortcuts", "keys": return .hotkeys
        case "modules": return .modules
        case "capture": return .capture
        case "sketch": return .sketch
        case "calendar": return .calendar
        case "pet": return .pet
        case "buttons": return .buttons
        case "devices": return .devices
        case "remote", "service": return .remoteService
        case "screen": return .screen
        case "about": return .about
        default: return nil
        }
    }
}
