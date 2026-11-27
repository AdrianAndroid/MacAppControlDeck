import AppKit
import SwiftUI

struct PetSettingsView: View {
    @ObservedObject private var settings = PetSettings.shared
    @ObservedObject private var registry = ModuleRegistry.shared
    @ObservedObject private var deck = DeckState.shared
    @ObservedObject private var dockSettings = PetDockSettings.shared
    @State private var runtimeLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard
                appearanceCard
                behaviorCard
                dockCard
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
                Image(systemName: settings.kind == .bongoCat ? "cat.fill" : "keyboard")
                    .font(.system(size: 48))
                    .frame(width: 100, height: 100)
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
                TabView(selection: $settings.kind) {
                    ForEach(PetKind.allCases) { kind in
                        Text(kind.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .tabItem { Text(kind.title) }
                            .tag(kind)
                    }
                }
                .frame(height: 70)

                Divider()

                HStack {
                    Text("尺寸")
                    Spacer()
                    Picker("", selection: $settings.size) {
                        ForEach(PetSize.allCases) { size in
                            Text("\(size.label)（\(Int(PetGeometry.windowSize(for: size, bongoCat: settings.kind == .bongoCat && settings.live2DMode && PetLive2DBridge.isBongoModel(settings.live2dModel), keyCat: settings.kind == .keyCat).width))px）").tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 330)
                }

                if settings.kind == .bongoCat && !settings.live2DMode && PetRasterAssets.shared == nil {
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
                if settings.kind == .bongoCat {
                    Toggle("悬停摸头（停在头顶会害羞）", isOn: $settings.hoverPetting)
                }
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

    private var dockCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("显示底部快捷栏", isOn: $dockSettings.enabled)
                Text("只取手机 Deck 里的「应用」按钮；快捷操作与命令按钮不显示。当前 \(deck.appButtons.count) 个。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("排序方式")
                    Picker("", selection: $dockSettings.sortMode) {
                        ForEach(PetDockSortMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                Text("同一排序同时作用于桌宠快捷栏与手机面板的应用区。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("冷却时间")
                    Picker("", selection: $dockSettings.cooldownMinutes) {
                        Text("关").tag(0)
                        Text("15 分钟").tag(15)
                        Text("30 分钟").tag(30)
                        Text("60 分钟").tag(60)
                    }
                    .frame(width: 160)
                    Text("刚点过的应用降权，但当前页位置不动")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                HStack {
                    Text("半衰期")
                    Picker("", selection: $dockSettings.halfLifeDays) {
                        Text("3 天").tag(3)
                        Text("7 天").tag(7)
                        Text("14 天").tag(14)
                    }
                    .frame(width: 160)
                    Text("更早的点击权重按 0.5 的 k 次方衰减")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Toggle("显示运行中圆点", isOn: $dockSettings.showRunningDot)
                Toggle("标记最近点击的图标（只标记最后一次）", isOn: $dockSettings.markLastClicked)
                Button("清空点击统计") {
                    AppDockOrdering.shared.resetStats()
                }
                Text("两端共用点击统计；排序只在「首次出现 / 点击后空闲 5 秒 / 改设置」时重算，不会在鼠标或手指下方跳位。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(6)
        } label: {
            Label("底部快捷栏", systemImage: "square.grid.3x1.below.line.grid.1x2")
        }
    }

    private var systemCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("允许覆盖全屏应用", isOn: $settings.allowFullScreen)
                Toggle("自己录屏时自动隐藏", isOn: $settings.hideDuringCapture)
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
                Text("只读取物理键码用于桌宠动作，不记录输入内容、不联网、不写键盘日志。没有权限时仍能显示、眨眼、跟随鼠标。")
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
