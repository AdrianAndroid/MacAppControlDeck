import Foundation
import Sparkle

/// 自动升级：封装 Sparkle 2。
///
/// 更新元数据来自 GitHub Releases 的 `appcast.xml`，更新包必须同时满足：
/// 1. 用内置 `SUPublicEDKey` 对应的 EdDSA 私钥签名（防篡改）；
/// 2. 与本机 App 使用同一份固定自签名证书（保 TCC 授权不失效）。
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    /// 发布通道：`releases/latest/download/appcast.xml` 是稳定地址，不需要 Pages。
    static let feedURL = "https://github.com/AdrianAndroid/MacAppControlDeck/releases/latest/download/appcast.xml"

    @Published private(set) var automaticallyChecks = true
    @Published private(set) var statusText = "尚未检查"
    @Published private(set) var canCheck = true

    private var controller: SPUStandardUpdaterController?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let status = "update.lastStatus"
        static let checkedAt = "update.lastCheckedAt"
    }

    private override init() {
        super.init()
        statusText = defaults.string(forKey: Keys.status) ?? "尚未检查"
    }

    func start() {
        guard controller == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        // 本 App 不允许静默安装：下载与安装都必须由用户确认。
        // （Info.plist 的 SUAllowsAutomaticUpdates=false 已经让它恒为 NO，这里再显式兜底。）
        if controller.updater.automaticallyDownloadsUpdates {
            controller.updater.automaticallyDownloadsUpdates = false
        }

        // 端到端验证用：启动即触发一次检查，正常使用不设置该变量。
        if ProcessInfo.processInfo.environment["DECK_UPDATE_CHECK_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.checkForUpdates()
            }
        }
    }

    /// 用户主动检查：有新版会走 Sparkle 标准弹窗，下载完成后由用户确认是否重启安装。
    func checkForUpdates() {
        start()
        guard let controller, controller.updater.canCheckForUpdates else {
            updateStatus("正在检查中，请稍候")
            return
        }
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        start()
        controller?.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? enabled
    }

    /// 供设置页显示：上次检查时间 + 结果。
    var detailText: String {
        guard let date = defaults.object(forKey: Keys.checkedAt) as? Date else { return statusText }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return "\(statusText) · \(formatter.string(from: date))"
    }

    private func updateStatus(_ text: String, stampDate: Bool = false) {
        statusText = text
        defaults.set(text, forKey: Keys.status)
        if stampDate {
            defaults.set(Date(), forKey: Keys.checkedAt)
        }
    }
}

extension UpdateController: SPUUpdaterDelegate {
    /// 测试通道：允许用环境变量把 feed 指向本地或镜像，正式运行时走 GitHub。
    func feedURLString(for updater: SPUUpdater) -> String? {
        let override = ProcessInfo.processInfo.environment["DECK_UPDATE_FEED"] ?? ""
        return override.isEmpty ? nil : override
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateStatus("发现新版本 \(item.displayVersionString)", stampDate: true)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        updateStatus("已是最新版本", stampDate: true)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        canCheck = updater.canCheckForUpdates
        if let error {
            updateStatus("检查失败：\(error.localizedDescription)", stampDate: true)
        }
    }
}
