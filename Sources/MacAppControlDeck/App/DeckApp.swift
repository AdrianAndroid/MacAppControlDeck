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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏应用：不显示 Dock 图标，不开主窗口。
        NSApp.setActivationPolicy(.accessory)

        // 每个功能模块独立启停；remote 启动自己的 HTTP 服务，capture 只注册本机菜单。
        ModuleRegistry.shared.register(RemoteControlModule())
        ModuleRegistry.shared.register(CaptureModule.shared)
        ModuleRegistry.shared.register(SketchModule.shared)
        GlobalHotKeys.shared.install()
        MenuBarController.shared.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出时只停服务，不改用户保存的模块开关。
        DeckState.shared.stop()
    }
}
