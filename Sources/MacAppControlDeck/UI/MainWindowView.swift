import SwiftUI
import AppKit
import ApplicationServices

final class DeckState: ObservableObject {
    static let shared = DeckState()
    @Published var serverStatus = ServerStatus(running: false, port: 0, errorText: nil)
    @Published var panelURL: URL?
    @Published var pairingCode: String?
    @Published var pairingExpiryText: String = ""
    @Published var buttons: [ButtonConfig] = []
    @Published var devices: [DeviceRecord] = []
    @Published var installedApps: [InstalledApp] = []
    @Published var accessibilityReady = AXIsProcessTrusted()
    @Published var inputMonitoringReady = CGPreflightListenEventAccess()
    @Published var missionControlSpaceSwitchEnabled = DeckState.readSpaceSwitchSetting()

    let store: ConfigStore
    let pairing = PairingManager()
    private let server: DeckHTTPServer
    private var expiryTimer: Timer?
    private var accessibilityTimer: Timer?

    init(injectedServer: DeckHTTPServer? = nil) {
        store = ConfigStore()
        let router = APIRouter(store: store, pairing: pairing, activator: AppControl())
        server = injectedServer ?? DeckHTTPServer(router: router)
        refreshAll()
    }

    func start() {
        guard !serverStatus.running else { return }
        serverStatus = server.start()
        panelURL = LANAddress.panelURL(port: server.port)
        refreshAll()
        pollAccessibility()
    }

    /// 定期轮询辅助功能授权状态，用户在系统设置授权后面板状态自动变绿。
    private func pollAccessibility() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.accessibilityReady = AXIsProcessTrusted()
                self?.inputMonitoringReady = CGPreflightListenEventAccess()
                self?.missionControlSpaceSwitchEnabled = DeckState.readSpaceSwitchSetting()
            }
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func readSpaceSwitchSetting() -> Bool {
        let value = CFPreferencesCopyAppValue("workspaces-auto-swoosh" as CFString,
                                              "com.apple.dock" as CFString)
        if let number = value as? NSNumber { return number.boolValue }
        return true
    }

    func openDesktopDockSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension?MissionControl") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openInputMonitoringSettings()
    }

    func stop() {
        server.stop()
        serverStatus = ServerStatus(running: false, port: 0, errorText: nil)
    }

    func refreshAll() {
        buttons = store.sortedButtons()
        devices = store.devices
    }

    func generatePairingCode() {
        pairingCode = pairing.newCode()
        startExpiryTimer()
    }

    private func startExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard let expiry = self.pairing.expiresAt else {
                    self.pairingCode = nil
                    self.pairingExpiryText = ""
                    self.expiryTimer?.invalidate()
                    return
                }
                let remaining = Int(expiry.timeIntervalSinceNow)
                self.pairingExpiryText = remaining > 0
                    ? String(format: "剩余 %d:%02d", remaining / 60, remaining % 60)
                    : ""
                if remaining <= 0 {
                    self.pairingCode = nil
                    self.pairingExpiryText = ""
                }
            }
        }
    }

    func revoke(_ device: DeviceRecord) {
        store.revokeDevice(token: device.token)
        devices = store.devices
    }

    func addInstalledApp(_ app: InstalledApp) {
        store.addButton(name: app.name, bundleID: app.bundleID, appPath: app.path)
        refreshAll()
    }

    func addShortcut(name: String, combo: ShortcutCombo) {
        store.addShortcutButton(name: name, combo: combo)
        refreshAll()
    }

    func updateShortcut(id: String, name: String?, combo: ShortcutCombo?) {
        store.updateShortcut(id: id, name: name, combo: combo)
        refreshAll()
    }

    func addCommand(name: String, appPath: String, bundleID: String, arguments: [String]) {
        store.addCommandButton(name: name, appPath: appPath, bundleID: bundleID, arguments: arguments)
        refreshAll()
    }

    var commandButtons: [ButtonConfig] { buttons.filter { $0.kind == .command } }
    var quickButtons: [ButtonConfig] { buttons.filter { $0.kind != .app } }

    var appButtons: [ButtonConfig] { buttons.filter { $0.kind == .app } }
    var shortcutButtons: [ButtonConfig] { buttons.filter { $0.kind == .shortcut } }

    func rename(_ button: ButtonConfig, to name: String) {
        store.renameButton(id: button.id, to: name)
        refreshAll()
    }

    func delete(_ button: ButtonConfig) {
        store.deleteButton(id: button.id)
        refreshAll()
    }

    func move(_ button: ButtonConfig, offset: Int) {
        store.moveButton(id: button.id, offset: offset)
        refreshAll()
    }
}

struct MainWindowView: View {
    @ObservedObject private var state = DeckState.shared
    @Environment(\.openWindow) private var openWindow
    @State private var pendingDelete: ButtonConfig?
    @State private var showAddSheet = false
    @State private var pendingRevoke: DeviceRecord?
    @State private var pendingRename: ButtonConfig?
    @State private var renameText = ""
    @State private var showShortcutSheet = false
    @State private var showCommandSheet = false
    @State private var editingShortcut: ButtonConfig?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                pairingCard
                buttonsCard
                devicesCard
                noteCard
            }
            .padding(20)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 600)
        .sheet(isPresented: $showAddSheet) {
            AddButtonSheet(state: state)
        }
        .sheet(isPresented: $showShortcutSheet) {
            ShortcutSheet(state: state, editing: nil)
        }
        .sheet(item: $editingShortcut) { button in
            ShortcutSheet(state: state, editing: button)
        }
        .sheet(isPresented: $showCommandSheet) {
            CommandSheet(state: state)
        }
        .confirmationDialog("确定删除按钮「\(pendingDelete?.name ?? "")」？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let button = pendingDelete { state.delete(button) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
        .confirmationDialog("撤销设备「\(pendingRevoke?.name ?? "")」的配对？撤销后该设备需要重新配对。", isPresented: Binding(
            get: { pendingRevoke != nil }, set: { if !$0 { pendingRevoke = nil } }), titleVisibility: .visible) {
            Button("撤销配对", role: .destructive) {
                if let device = pendingRevoke { state.revoke(device) }
                pendingRevoke = nil
            }
            Button("取消", role: .cancel) { pendingRevoke = nil }
        }
        .alert("重命名按钮", isPresented: Binding(
            get: { pendingRename != nil }, set: { if !$0 { pendingRename = nil } })) {
            TextField("按钮名称", text: $renameText)
            Button("保存") {
                if let button = pendingRename, !renameText.isEmpty {
                    state.rename(button, to: renameText)
                }
                pendingRename = nil
            }
            Button("取消", role: .cancel) { pendingRename = nil }
        }
        .onAppear { state.start() }
    }

    private var headerCard: some View {
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
                        state.stop()
                        state.start()
                    }
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.accessibilityReady ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(state.accessibilityReady
                         ? "辅助功能权限：已授权（跨桌面切换可用）"
                         : "辅助功能权限：未授权（无法自动切换到其他桌面）")
                        .font(.subheadline)
                    Spacer()
                    if !state.accessibilityReady {
                        Button("去授权（打开系统设置）") { state.openAccessibilitySettings() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.inputMonitoringReady ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(state.inputMonitoringReady
                         ? "输入监控：已授权"
                         : "输入监控：未授权（部分第三方应用的全局热键可能收不到按键）")
                        .font(.subheadline)
                    Spacer()
                    if !state.inputMonitoringReady {
                        Button("去授权（打开系统设置）") { state.requestInputMonitoring() }
                            .buttonStyle(.borderedProminent)
                    }
                }
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
                    Button("打开调度中心设置") { state.openDesktopDockSettings() }
                        .buttonStyle(.bordered)
                }
                HStack {
                    Text(state.panelURL?.absoluteString ?? "未获取到局域网地址")
                        .font(.system(size: 14, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Button("复制地址") {
                        if let url = state.panelURL { UIPasteboardLike.copy(url.absoluteString) }
                    }
                    .disabled(state.panelURL == nil)
                }
                Text("手机和 Mac 连接同一局域网，用 Safari 打开上面的地址。明文 HTTP 可能被同网段设备嗅探，仅建议在可信网络使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(4)
        } label: {
            Text("服务状态").font(.headline)
        }
    }

    @ViewBuilder
    private var pairingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let code = state.pairingCode {
                    HStack(alignment: .center, spacing: 16) {
                        Text(code)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
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
                        Text("配对成功后手机会获得随机凭证，可在下方撤销。")
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

    private var buttonsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Menu("添加按钮") {
                        Button("添加应用按钮…") {
                            state.installedApps = AppEnumerator.installedApps()
                            showAddSheet = true
                        }
                        Button("添加快捷操作…") {
                            showShortcutSheet = true
                        }
                        Button("添加命令按钮…") {
                            showCommandSheet = true
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Spacer()
                    Text("共 \(state.buttons.count) 个")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if state.buttons.isEmpty {
                    Text("还没有按钮，点击「添加按钮」创建。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    if !state.appButtons.isEmpty {
                        sectionHeader("应用")
                        ForEach(state.appButtons) { button in
                            buttonRow(button)
                            Divider()
                        }
                    }
                    if !state.quickButtons.isEmpty {
                        sectionHeader("快捷操作")
                        ForEach(state.quickButtons) { button in
                            if button.kind == .command {
                                commandRow(button)
                            } else {
                                shortcutRow(button)
                            }
                            Divider()
                        }
                    }
                }
            }
            .padding(4)
        } label: {
            Text("按钮配置").font(.headline)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func buttonRow(_ button: ButtonConfig) -> some View {
        let installed = FileManager.default.fileExists(atPath: button.appPath)
        return HStack(spacing: 12) {
            AppIconView(path: button.appPath)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text(installed ? button.bundleID : "应用缺失：\(button.bundleID)")
                    .font(.caption2)
                    .foregroundStyle(installed ? Color.secondary : Color.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                if button.kind == .shortcut {
                    Button("编辑组合…") { editingShortcut = button }
                }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func commandRow(_ button: ButtonConfig) -> some View {
        HStack(spacing: 12) {
            Text("▶")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 64, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25)))
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text("命令 · \((button.appPath as NSString).lastPathComponent) \((button.commandArguments ?? []).joined(separator: " "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func shortcutRow(_ button: ButtonConfig) -> some View {
        HStack(spacing: 12) {
            Text(button.displaySymbol ?? "—")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .frame(width: 64, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25)))
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text("快捷操作 · \(button.displaySymbol ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                Button("编辑组合…") { editingShortcut = button }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private var devicesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if state.devices.isEmpty {
                    Text("暂无已配对设备。")
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
        } label: {
            Text("已配对设备").font(.headline)
        }
    }

    private var noteCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("权限与调度中心状态见上方「服务状态」区；开关未开启时跨桌面切换不可用。")
                Text("全屏空间与多显示器可能不完全跟随调度中心设置，属系统行为。")
                Text("应用最小化窗口的恢复由系统与目标应用决定；无法确认时面板会显示“未确认”，不会谎报成功。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(4)
        } label: {
            Text("说明与限制").font(.headline)
        }
    }
}

struct AppIconView: View {
    var path: String
    var size: CGFloat { 34 }
    var body: some View {
        if let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image).resizable().frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.35))
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
                .frame(width: size, height: size)
        }
    }
}

enum UIPasteboardLike {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct AddButtonSheet: View {
    @ObservedObject var state: DeckState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择要绑定的应用").font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }.padding(12)
            TextField("搜索应用名称", text: $searchText).textFieldStyle(.roundedBorder).padding(.horizontal, 12)
            List(filteredApps) { app in
                HStack {
                    AppIconView(path: app.path).frame(width: 30, height: 30)
                    VStack(alignment: .leading) {
                        Text(app.name).font(.callout)
                        Text(app.bundleID).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if state.buttons.contains(where: { $0.bundleID == app.bundleID }) {
                        Text("已添加").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("添加") { state.addInstalledApp(app) }.buttonStyle(.bordered)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 480, height: 500)
    }

    private var filteredApps: [InstalledApp] {
        searchText.isEmpty ? state.installedApps
            : state.installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}
