import SwiftUI
import ServiceManagement

enum SettingsTab: Hashable {
    case general
    case modules
    case capture
    case buttons
    case devices
    case about
}

struct SettingsView: View {
    @ObservedObject private var state = DeckState.shared
    @State private var selection: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("应用") {
                    sidebarRow(.general, "通用", "gearshape")
                }
                Section("模块") {
                    sidebarRow(.modules, "模块", "square.stack.3d.up")
                }
                Section("电脑遥控") {
                    sidebarRow(.buttons, "按钮", "square.grid.2x2")
                    sidebarRow(.devices, "设备", "iphone")
                }
                Section("截图与录屏") {
                    sidebarRow(.capture, "截图与录屏", "camera.viewfinder")
                }
                Section("关于") {
                    sidebarRow(.about, "关于", "info.circle")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            detailView
        }
        .frame(width: 840, height: 640)
        .onAppear { applyRequestedTab() }
        .onChange(of: state.requestedSettingsTab) { _, _ in
            applyRequestedTab()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .modules:
            ModulesSettingsView(onOpenCaptureSettings: { selection = .capture })
        case .capture:
            CaptureSettingsView()
        case .buttons:
            ButtonsSettingsView()
        case .devices:
            DevicesSettingsView()
        case .about:
            AboutSettingsView()
        }
    }

    private func sidebarRow(_ tab: SettingsTab, _ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).tag(tab)
    }

    private func applyRequestedTab() {
        guard let requested = state.requestedSettingsTab else { return }
        selection = requested
        state.requestedSettingsTab = nil
    }
}

// MARK: - 模块

struct ModulesSettingsView: View {
    @ObservedObject private var registry = ModuleRegistry.shared
    let onOpenCaptureSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("每个功能是独立模块：自己的服务、数据、权限和生命周期。关闭一个模块不会影响另一个。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(Array(registry.modules.enumerated()), id: \.offset) { _, module in
                    moduleCard(module)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func moduleCard(_ module: any FeatureModule) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: module.systemImage)
                        .font(.title2)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title).font(.headline)
                        Text(module.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Toggle("启用", isOn: Binding(
                        get: { registry.isEnabled(module.id) },
                        set: { registry.setEnabled(module.id, $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("\(module.title)开关")
                }

                if module.id == CaptureModule.id, registry.isEnabled(module.id) {
                    HStack {
                        Button("截图设置…") { onOpenCaptureSettings() }
                            .buttonStyle(.bordered)
                        Text("输出目录、剪贴板、屏幕录制权限。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(module.title).font(.headline)
        }
    }
}

// MARK: - 通用

struct GeneralSettingsView: View {
    @ObservedObject private var state = DeckState.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                serviceCard
                permissionsCard
                pairingCard
                startupCard
                Text("明文 HTTP 可能被同网段设备嗅探，仅建议在可信网络使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var serviceCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.serverStatus.running ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(state.serverStatus.running
                         ? "服务运行中 · 端口 \(String(state.serverStatus.port))"
                         : "服务未运行\(state.serverStatus.errorText.map { "（\($0)）" } ?? "")")
                        .font(.headline)
                    Spacer()
                    Button(state.serverStatus.running ? "重新启动服务" : "启动服务") {
                        state.restart()
                    }
                }

                HStack {
                    Text(state.panelURL?.absoluteString ?? "未获取到局域网地址")
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Button("复制") { state.copyPanelURL() }
                        .disabled(state.panelURL == nil)
                    Button("打开") { state.openPanelInBrowser() }
                        .disabled(state.panelURL == nil)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("远程面板").font(.headline)
        }
    }

    private var permissionsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                permissionRow(
                    ok: state.accessibilityReady,
                    title: state.accessibilityReady
                        ? "辅助功能：已授权（跨桌面切换可用）"
                        : "辅助功能：未授权（无法自动切换到其他桌面）",
                    actionTitle: state.accessibilityReady ? nil : "去授权",
                    action: { state.openAccessibilitySettings() }
                )
                permissionRow(
                    ok: state.inputMonitoringReady,
                    title: state.inputMonitoringReady
                        ? "输入监控：已授权"
                        : "输入监控：未授权（部分第三方应用的全局热键可能收不到按键）",
                    actionTitle: state.inputMonitoringReady ? nil : "去授权",
                    action: { state.requestInputMonitoring() }
                )
                permissionRow(
                    ok: state.automationReady,
                    title: state.automationReady
                        ? "自动化：已允许控制 System Events（桌面左右切换可用）"
                        : "自动化：未允许控制 System Events（桌面左右切换不可用）",
                    actionTitle: state.automationReady ? nil : "去授权",
                    action: { state.requestAutomationPermission() }
                )
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.missionControlSpaceSwitchEnabled ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.missionControlSpaceSwitchEnabled
                             ? "调度中心：切换应用时跟随窗口所在空间（已开启）"
                             : "调度中心：未开启「切换到包含窗口的空间」，跨桌面切换不可用")
                            .font(.subheadline)
                        Text("系统设置 → 桌面与程序坞 → 调度中心：切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                     }
                    Spacer()
                    Button("打开设置") { state.openDesktopDockSettings() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("权限").font(.headline)
        }
    }

    private func permissionRow(ok: Bool,
                               title: String,
                               actionTitle: String?,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(title).font(.subheadline)
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var pairingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let code = state.pairingCode {
                    HStack(alignment: .center, spacing: 16) {
                        Text(code)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.pairingExpiryText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("错误 3 次将作废")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("复制") { UIPasteboardLike.copy(code) }
                        Button("作废") {
                            state.pairing.invalidate()
                            state.pairingCode = nil
                        }
                    }
                    Text("在手机面板输入此配对码完成配对。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button("生成 6 位配对码（2 分钟有效）") { state.generatePairingCode() }
                            .buttonStyle(.borderedProminent)
                        Text("配对成功后手机会获得随机凭证，可在「设备」中撤销。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("设备配对").font(.headline)
        }
    }

    private var startupCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("登录时自动启动（菜单栏常驻）", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLoginItem(enabled: newValue)
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("需要应用位于 /Applications 下，且使用稳定的代码签名。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("启动").font(.headline)
        }
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "设置失败：\(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - 设备

struct DevicesSettingsView: View {
    @ObservedObject private var state = DeckState.shared
    @State private var pendingRevoke: DeviceRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.devices.isEmpty {
                            Text("暂无已配对设备。在「通用」里生成配对码，用手机面板完成配对。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(state.devices) { device in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name).font(.callout)
                                        Text("配对于 \(device.pairedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("撤销配对") { pendingRevoke = device }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("已配对设备").font(.headline)
                }

                Text("撤销后该设备需要重新配对；已发出的手机端 token 会立即失效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .confirmationDialog("撤销设备「\(pendingRevoke?.name ?? "")」的配对？",
                            isPresented: Binding(
                                get: { pendingRevoke != nil },
                                set: { if !$0 { pendingRevoke = nil } }),
                            titleVisibility: .visible) {
            Button("撤销配对", role: .destructive) {
                if let device = pendingRevoke { state.revoke(device) }
                pendingRevoke = nil
            }
            Button("取消", role: .cancel) { pendingRevoke = nil }
        }
    }
}

// MARK: - 关于

struct AboutSettingsView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short)（build \(build)）"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AppIconView(path: Bundle.main.bundlePath).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac 应用快捷控制台").font(.title3.weight(.semibold))
                        Text("版本 \(version)").font(.caption).foregroundStyle(.secondary)
                        Text("局域网内用手机遥控 Mac：启动应用、注入快捷键、执行应用内置命令。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("全屏空间与多显示器可能不完全跟随调度中心设置，属系统行为。")
                        Text("应用最小化窗口的恢复由系统与目标应用决定；无法确认时面板会显示“未确认”，不会谎报成功。")
                        Text("菜单栏常驻运行，关闭设置窗口不会退出服务。")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                } label: {
                    Text("说明与限制").font(.headline)
                }
            }
            .padding(20)
        }
    }
}
