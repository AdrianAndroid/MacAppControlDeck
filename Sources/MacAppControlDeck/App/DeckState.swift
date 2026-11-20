import SwiftUI
import AppKit
import ApplicationServices
import Carbon

/// 应用运行状态的唯一持有者：服务、按钮、设备、权限、配对。
/// 菜单栏与设置窗口都观察同一个实例，避免两套状态。
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
    @Published var automationReady = DeckState.readAutomationPermission()
    /// 从菜单栏跳到设置时指定要显示的标签页（例如「配对手机…」定位到通用）。
    @Published var requestedSettingsTab: SettingsTab?

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
                self?.automationReady = DeckState.readAutomationPermission()
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

    /// 检测是否允许向 System Events 发送 Apple 事件（桌面切换依赖）。
    static func readAutomationPermission() -> Bool {
        var address = AEAddressDesc()
        let bytes = Array("com.apple.systemevents".utf8)
        let created = bytes.withUnsafeBufferPointer { buffer in
            AECreateDesc(DescType(typeApplicationBundleID), buffer.baseAddress, bytes.count, &address)
        }
        guard created == noErr else { return false }
        defer { AEDisposeDesc(&address) }
        let status = AEDeterminePermissionToAutomateTarget(&address,
                                                          AEEventClass(typeWildCard),
                                                          AEEventID(typeWildCard),
                                                          false)
        return status == noErr
    }

    func requestAutomationPermission() {
        var address = AEAddressDesc()
        let bytes = Array("com.apple.systemevents".utf8)
        let created = bytes.withUnsafeBufferPointer { buffer in
            AECreateDesc(DescType(typeApplicationBundleID), buffer.baseAddress, bytes.count, &address)
        }
        if created == noErr {
            _ = AEDeterminePermissionToAutomateTarget(&address,
                                                      AEEventClass(typeWildCard),
                                                      AEEventID(typeWildCard),
                                                      true)
            AEDisposeDesc(&address)
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
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

    func restart() {
        stop()
        start()
    }

    func refreshAll() {
        buttons = store.sortedButtons()
        devices = store.devices
    }

    func generatePairingCode() {
        pairingCode = pairing.newCode()
        updateExpiryText()
        startExpiryTimer()
    }

    private func startExpiryTimer() {
        expiryTimer?.invalidate()
        // 用 .common 模式，菜单打开/窗口拖拽时倒计时也不会停。
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateExpiryText()
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    /// 同步刷新倒计时文本；配对码过期后立即清掉，避免界面显示一个已经失效的码。
    private func updateExpiryText() {
        guard let expiry = pairing.expiresAt else {
            pairingCode = nil
            pairingExpiryText = ""
            expiryTimer?.invalidate()
            return
        }
        let remaining = Int(expiry.timeIntervalSinceNow)
        guard remaining > 0 else {
            pairingCode = nil
            pairingExpiryText = ""
            pairing.invalidate()
            expiryTimer?.invalidate()
            return
        }
        pairingExpiryText = String(format: "剩余 %d:%02d", remaining / 60, remaining % 60)
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

    func moveToIndex(_ button: ButtonConfig, toIndex: Int) {
        store.moveButton(id: button.id, toIndex: toIndex)
        refreshAll()
    }

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

    // MARK: - 菜单栏与设置共用的小工具

    /// 菜单顶部显示的面板地址（服务未运行时给出原因）。
    var panelAddressText: String {
        if let url = panelURL, let host = url.host {
            let port = url.port ?? Int(serverStatus.port)
            return "\(host):\(port)"
        }
        return serverStatus.running ? "端口 \(serverStatus.port)" : "服务未运行"
    }

    func copyPanelURL() {
        guard let text = panelURL?.absoluteString else { return }
        UIPasteboardLike.copy(text)
    }

    func openPanelInBrowser() {
        guard let url = panelURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// 菜单栏里点击一个功能按钮：与手机端 /api/activate 走同一套控制逻辑。
    func perform(_ button: ButtonConfig) {
        QuickActionRunner.shared.run(button) { [weak self] failure in
            guard let failure else { return }
            self?.presentFailure(title: "「\(button.name)」未完成", message: failure)
        }
    }

    private func presentFailure(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    func menuTitle(for button: ButtonConfig) -> String {
        switch button.kind {
        case .app:
            return isInstalled(button) ? button.name : "\(button.name)（缺失）"
        case .shortcut:
            return "\(button.name)   \(button.displaySymbol ?? "")"
        case .command:
            return button.name
        }
    }

    /// 菜单项图标：应用用真实图标，快捷操作/命令用 SF Symbol。
    func icon(for button: ButtonConfig) -> NSImage {
        if button.kind == .app, !button.appPath.isEmpty {
            let icon = NSWorkspace.shared.icon(forFile: button.appPath)
            let copy = (icon.copy() as? NSImage) ?? icon
            copy.size = NSSize(width: 16, height: 16)
            return copy
        }
        let symbol = button.kind == .command ? "terminal" : "keyboard"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    func isInstalled(_ button: ButtonConfig) -> Bool {
        button.kind != .app || (!button.appPath.isEmpty && FileManager.default.fileExists(atPath: button.appPath))
    }
}
