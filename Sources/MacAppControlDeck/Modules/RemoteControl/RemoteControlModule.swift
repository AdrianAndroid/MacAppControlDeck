import AppKit
import SwiftUI

/// 电脑遥控模块：手机通过局域网面板控制 Mac 应用、快捷键和命令。
/// 它的服务、配对、设备、按钮配置都在这一模块内，不与截图模块共享状态。
final class RemoteControlModule: FeatureModule {
    static let id = "remote"

    var id: String { Self.id }
    var title: String { "电脑遥控" }
    var summary: String { "手机通过局域网面板控制 Mac 应用、快捷键和命令。" }
    var systemImage: String { "iphone.radiowaves.left.and.right" }
    var defaultEnabled: Bool { true }

    func start() {
        DeckState.shared.start()
    }

    func stop() {
        DeckState.shared.stop()
    }

    func settingsView() -> AnyView {
        AnyView(RemoteControlModuleSettingsView())
    }
}

private struct RemoteControlModuleSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手机配对、按钮配置和设备管理分别在「按钮」与「设备」页。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
