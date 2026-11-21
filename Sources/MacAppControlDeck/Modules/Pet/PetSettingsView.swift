import AppKit
import SwiftUI

struct PetSettingsView: View {
    @ObservedObject private var settings = PetSettings.shared
    @ObservedObject private var registry = ModuleRegistry.shared
    @ObservedObject private var deck = DeckState.shared
    @State private var runtimeLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard
                appearanceCard
                behaviorCard
                systemCard
                privacyCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { runtimeLoaded = PetModule.shared.isRuntimeLoaded }
        .onReceive(NotificationCenter.default.publisher(for: PetModule.runtimeDidChange)) { _ in
            runtimeLoaded = PetModule.shared.isRuntimeLoaded
        }
    }

    private var statusCard: some View {
        GroupBox {
            HStack(spacing: 16) {
                PetLivePreview(settings: settings)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(registry.isEnabled(PetModule.id) ? Color.green : Color.orange)
                            .frame(width: 9, height: 9)
                        Text(registry.isEnabled(PetModule.id) ? "桌面宠物已启用" : "桌面宠物已关闭")
                            .font(.headline)
                    }
                    Text(settings.visible ? "桌宠正在桌面上；隐藏会释放窗口和监听。" : "桌宠当前隐藏；打开后才会创建窗口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(settings.visible ? "隐藏桌宠" : "显示桌宠") {
                            if settings.visible {
                                PetModule.shared.hide()
                            } else {
                                PetModule.shared.open()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("重置位置") {
                            PetModule.shared.resetPosition()
                        }
                        Spacer()
                        Text("快捷键 ⌃⌥P")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(6)
        } label: {
            Label("桌宠", systemImage: "cat.fill")
        }
    }

    private var appearanceCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text("皮肤")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if PetRasterAssets.shared != nil {
                    Text("当前使用 v4 实拍分层素材：黑猫蹲坐、木桌白键盘白鼠标，眼球跟随全屏光标，头部随视线微转。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        ForEach(PetSkinCatalog.all) { skin in
                            Button {
                                settings.chooseSkin(skin.id)
                            } label: {
                                PetSkinSwatch(skin: skin, selected: settings.skinID == skin.id)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }

                Divider()

                HStack {
                    Text("尺寸")
                    Spacer()
                    Picker("", selection: $settings.size) {
                        ForEach(PetSize.allCases) { size in
                            Text("\(size.label)（\(Int(PetGeometry.windowSize(for: size).width))px）").tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 330)
                }

                if PetRasterAssets.shared == nil {
                    HStack {
                        Text("键盘主题")
                        Spacer()
                        Picker("", selection: $settings.keyboardTheme) {
                            ForEach(PetKeyboardTheme.allCases) { theme in
                                Text(theme.label).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }
                }

                Text("切换尺寸时窗口、猫、键盘和点击拦截区一起缩放，底部中心保持不动。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("外观", systemImage: "paintpalette")
        }
    }

    private var behaviorCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("暂停互动（窗口保留，停止键鼠响应）", isOn: $settings.paused)
                Toggle("点击穿透（完全点不到，需从菜单栏恢复）", isOn: $settings.clickThrough)
                Toggle("锁定位置（还能摸头，不能拖动）", isOn: $settings.locked)
                Toggle("鼠标跟随（眼珠跟随光标）", isOn: $settings.followMouse)
                Toggle("悬停摸头（停在头顶会害羞）", isOn: $settings.hoverPetting)
                HStack {
                    Text("空闲睡觉")
                    Spacer()
                    Picker("", selection: $settings.sleepMinutes) {
                        Text("不睡").tag(0)
                        Text("5 分钟").tag(5)
                        Text("10 分钟").tag(10)
                        Text("20 分钟").tag(20)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                Text("敲键盘、动鼠标、滚轮都会把它叫醒，并临时升到 30fps。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("行为", systemImage: "hand.tap")
        }
    }

    private var systemCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("允许覆盖全屏应用", isOn: $settings.allowFullScreen)
                Toggle("自己录屏时自动隐藏", isOn: $settings.hideDuringCapture)
                Toggle("启动时随机换一套皮肤", isOn: $settings.randomSkinOnLaunch)
                Text("锁屏、屏幕休眠、安全输入时自动暂停；恢复后不会覆盖你手动设置的暂停。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("系统边界", systemImage: "display")
        }
    }

    private var privacyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(deck.inputMonitoringReady ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(deck.inputMonitoringReady ? "输入监控已授权" : "输入监控未授权，桌宠处于静态模式")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if !deck.inputMonitoringReady {
                        Button("去授权") { deck.requestInputMonitoring() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("打开系统设置") { deck.openInputMonitoringSettings() }
                    }
                }
                Text("只读取键码所在的左/中/右/功能区，不记录字符、不联网、不写键盘日志。没有权限时仍能显示、眨眼、跟随鼠标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if runtimeLoaded {
                    Text("运行时已加载；隐藏桌宠会释放监听与窗口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
        } label: {
            Label("权限与隐私", systemImage: "lock.shield")
        }
    }
}
