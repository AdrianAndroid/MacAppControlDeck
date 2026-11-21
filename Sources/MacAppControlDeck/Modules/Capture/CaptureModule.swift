import AppKit
import MacShotKit
import SwiftUI

/// 截图与录屏模块：Mac 本机功能，不注册 HTTP 路由、不出现在手机面板。
@MainActor final class CaptureModule: FeatureModule {
    static let id = "capture"
    static let shared = CaptureModule()

    var id: String { Self.id }
    var title: String { "截图与录屏" }
    var summary: String { "在 Mac 本机截图、标注、OCR、录屏和 GIF；不经过手机，也不占用遥控服务。" }
    var systemImage: String { "camera.viewfinder" }
    var defaultEnabled: Bool { true }

    func start() {
        syncDirectories()
    }

    func stop() {
        MacShotController.shared.stopRecording()
    }

    func menuItems() -> [NSMenuItem] {
        syncDirectories()
        let parent = NSMenuItem(title: "截图与录屏", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        parent.identifier = NSUserInterfaceItemIdentifier("capture.root")

        let submenu = NSMenu(title: "截图与录屏")
        parent.submenu = submenu

        var items: [NSMenuItem] = []
        if MacShotController.shared.isRecording {
            let stop = item("停止录屏", #selector(stopRecording), "stop.circle.fill")
            stop.identifier = NSUserInterfaceItemIdentifier("capture.stop")
            items.append(stop)
        }

        submenu.addItem(item("全屏截图", #selector(captureFullScreen), "camera"))
        submenu.addItem(item("全屏截图（全部显示器拼接）", #selector(captureAllScreens), "display"))
        submenu.addItem(item("区域截图", #selector(captureArea), "rectangle.dashed"))
        submenu.addItem(item("窗口截图", #selector(captureWindow), "rectangle.on.rectangle"))
        submenu.addItem(item("滚动截图（区域）", #selector(scrollCapture), "scroll"))
        submenu.addItem(item("快速保存（区域）", #selector(quickSaveArea), "square.and.arrow.down"))
        submenu.addItem(item("快速 OCR（区域）", #selector(quickOCRArea), "text.viewfinder"))
        submenu.addItem(.separator())

        let delayItem = NSMenuItem(title: "截图延时", action: nil, keyEquivalent: "")
        delayItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        delayItem.identifier = NSUserInterfaceItemIdentifier("capture.delay")
        let delayMenu = NSMenu(title: "截图延时")
        for seconds in [0, 3, 5, 10, 30] {
            let title = seconds == 0 ? "无延时" : "\(seconds) 秒"
            let child = NSMenuItem(title: title,
                                   action: #selector(setCaptureDelay(_:)),
                                   keyEquivalent: "")
            child.target = self
            child.representedObject = seconds
            child.identifier = NSUserInterfaceItemIdentifier("capture.delay.\(seconds)")
            child.state = Int(MacShotController.shared.captureDelay) == seconds ? .on : .off
            delayMenu.addItem(child)
        }
        delayItem.submenu = delayMenu
        submenu.addItem(delayItem)

        let presetItem = NSMenuItem(title: "选区比例 / 尺寸", action: nil, keyEquivalent: "")
        presetItem.image = NSImage(systemSymbolName: "aspectratio", accessibilityDescription: nil)
        presetItem.identifier = NSUserInterfaceItemIdentifier("capture.preset")
        let presetMenu = NSMenu(title: "选区比例 / 尺寸")
        for preset in CaptureSelectionPreset.allCases {
            let child = NSMenuItem(title: preset.label,
                                   action: #selector(setSelectionPreset(_:)),
                                   keyEquivalent: "")
            child.target = self
            child.representedObject = preset.label
            child.state = MacShotController.shared.selectionPreset == preset ? .on : .off
            presetMenu.addItem(child)
        }
        presetItem.submenu = presetMenu
        submenu.addItem(presetItem)
        submenu.addItem(.separator())

        submenu.addItem(item("录制屏幕（区域）", #selector(recordArea), "record.circle"))
        submenu.addItem(item("录制屏幕（全屏）", #selector(recordFullScreen), "record.circle.fill"))
        submenu.addItem(item("录制窗口", #selector(recordWindow), "rectangle.dashed.badge.record"))
        submenu.addItem(item("录制 GIF（区域）", #selector(recordGIF), "photo.stack"))
        if MacShotController.shared.isRecording {
            submenu.addItem(item("停止录屏", #selector(stopRecording), "stop.circle.fill"))
        }
        submenu.addItem(.separator())
        let historyItem = NSMenuItem(title: "最近截图", action: nil, keyEquivalent: "")
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        historyItem.identifier = NSUserInterfaceItemIdentifier("capture.history")
        let historyMenu = NSMenu(title: "最近截图")
        let urls = CaptureHistoryStore.shared.urls.prefix(12)
        if urls.isEmpty {
            let empty = NSMenuItem(title: "暂无截图", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
        } else {
            for url in urls {
                let child = NSMenuItem(title: url.lastPathComponent,
                                       action: #selector(openRecentCapture(_:)),
                                       keyEquivalent: "")
                child.target = self
                child.representedObject = url
                child.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                historyMenu.addItem(child)
            }
            historyMenu.addItem(.separator())
            let clear = NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "")
            clear.target = self
            historyMenu.addItem(clear)
        }
        historyItem.submenu = historyMenu
        submenu.addItem(historyItem)
        submenu.addItem(item("截图历史…", #selector(showHistoryOverlay), "square.grid.2x2"))
        submenu.addItem(item("钉剪贴板内容", #selector(pinClipboardContent), "pin"))
        submenu.addItem(item("打开截图目录", #selector(openCaptureFolder), "folder"))
        submenu.addItem(item("截图与录屏设置…", #selector(openCaptureSettings), "gearshape"))

        parent.submenu = submenu
        items.append(parent)
        return items
    }

    func settingsView() -> AnyView {
        AnyView(CaptureSettingsView())
    }

    // MARK: - 截图

    @objc func captureAllScreens() {
        MacShotController.shared.captureAllScreens()
    }

    @objc func captureFullScreen() {
        syncDirectories()
        MacShotController.shared.captureFullScreen()
    }

    @objc func captureArea() {
        syncDirectories()
        MacShotController.shared.captureArea()
    }

    @objc func captureWindow() {
        syncDirectories()
        MacShotController.shared.captureWindow()
    }

    @objc func quickSaveArea() {
        syncDirectories()
        MacShotController.shared.quickSaveArea()
    }

    @objc func scrollCapture() {
        syncDirectories()
        MacShotController.shared.scrollCapture()
    }

    @objc func quickOCRArea() {
        syncDirectories()
        MacShotController.shared.quickOCRArea()
    }

    @objc func setSelectionPreset(_ sender: NSMenuItem) {
        guard let label = sender.representedObject as? String else { return }
        if let preset = CaptureSelectionPreset.allCases.first(where: { $0.label == label }) {
            MacShotController.shared.selectionPreset = preset
        }
    }

    @objc func setCaptureDelay(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        MacShotController.shared.captureDelay = TimeInterval(seconds)
        CapturePreferences.shared.captureDelay = seconds
    }

    @objc func reopenLastCapture(_ sender: NSMenuItem) {
        MacShotController.shared.reopenLastEditSession()
    }

    @objc func openRecentCapture(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        MacShotController.shared.openRecentCapture(url)
    }

    @objc func clearHistory() {
        CaptureHistoryStore.shared.clear()
    }

    // MARK: - 录屏

    @objc func recordArea() {
        startRecording(format: .mp4, target: .area)
    }

    @objc func recordFullScreen() {
        startRecording(format: .mp4, target: .fullScreen)
    }

    @objc func recordWindow() {
        startRecording(format: .mp4, target: .window)
    }

    @objc func recordGIF() {
        startRecording(format: .gif, target: .area)
    }

    @objc func stopRecording() {
        MacShotController.shared.stopRecording()
        NotificationCenter.default.post(name: .captureRecordingDidStop, object: nil)
    }

    private func startRecording(format: RecordingFormat, target: RecordingTargetMode) {
        MacShotController.shared.startRecording(format: format, target: target)
        NotificationCenter.default.post(name: .captureRecordingDidStart, object: nil)
        // 录屏可能因为权限或用户取消而立即失败，下一轮检查真实状态。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !MacShotController.shared.isRecording else { return }
            NotificationCenter.default.post(name: .captureRecordingDidStop, object: nil)
        }
    }

    // MARK: - 其他

    @objc func pinClipboardContent() {
        ClipboardPinService.pinClipboard()
    }

    @objc func openHistoryFolder() {
        NSWorkspace.shared.activateFileViewerSelecting(
            [MacShotController.shared.outputDirectory])
    }

    @objc func showHistoryOverlay() {
        openHistoryFolder()
    }

    @objc func openCaptureFolder() {
        syncDirectories()
        NSWorkspace.shared.open(MacShotController.shared.outputDirectory)
    }

    @objc func openCaptureSettings() {
        MenuBarController.shared.openSettings(tab: .capture)
    }

    private func syncDirectories() {
        let prefs = CapturePreferences.shared
        MacShotController.shared.outputDirectory = prefs.directoryURL
        MacShotController.shared.recordingDirectory = prefs.recordingDirectoryURL
        MacShotController.shared.recordingOptions.systemAudio = prefs.recordingSystemAudio
        MacShotController.shared.recordingOptions.showsCursor = prefs.recordingCursor
        MacShotController.shared.recordingOptions.microphone = prefs.recordingMicrophone
        MacShotController.shared.recordingOptions.fps = prefs.recordingFPS
        MacShotController.shared.recordingOptions.gifFPS = prefs.gifFPS
        MacShotController.shared.imageFormat = prefs.imageFormat.rawValue
        MacShotController.shared.imageQuality = prefs.imageQuality
        MacShotController.shared.captureDelay = TimeInterval(prefs.captureDelay)
        MacShotController.shared.playShutterSound = prefs.shutterSound
        MacShotController.shared.saveToFile = prefs.saveToFile
        MacShotController.shared.copyToClipboard = prefs.copyToClipboard
        MacShotController.shared.showFloatingThumbnail = prefs.showFloatingThumbnail

        // 覆盖层/录屏引擎使用上游的 UserDefaults 键，这里保持与模块偏好一致，
        // 避免覆盖层里显示的帧率/音频选项与实际录制不一致。
        let defaults = UserDefaults.standard
        defaults.set(prefs.recordingFPS, forKey: "recordingFPS")
        defaults.set(prefs.recordingSystemAudio, forKey: "recordSystemAudio")
        defaults.set(prefs.recordingMicrophone, forKey: "recordMicAudio")
        defaults.set(prefs.captureDelay, forKey: "captureDelaySeconds")
        defaults.set(prefs.recordingCursor, forKey: "captureCursor")
        defaults.set(prefs.showFloatingThumbnail, forKey: "showFloatingThumbnail")
    }

    private func item(_ title: String, _ selector: Selector, _ symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.identifier = NSUserInterfaceItemIdentifier("capture.\(Self.slug(title))")
        return item
    }

    static func slug(_ title: String) -> String {
        title.replacingOccurrences(of: "（", with: "-")
            .replacingOccurrences(of: "）", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}


extension Notification.Name {
    static let captureRecordingDidStart = Notification.Name("CaptureModule.recordingDidStart")
    static let captureRecordingDidStop = Notification.Name("CaptureModule.recordingDidStop")
}
