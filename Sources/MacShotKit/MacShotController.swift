import AppKit
import AVFoundation
import CoreGraphics

public enum CaptureSelectionPreset: Equatable, CaseIterable {
    case free
    case ratio(String, CGFloat)
    case pixels(String, Int, Int)

    public static var allCases: [CaptureSelectionPreset] {
        [.free, .ratio("1:1", 1), .ratio("4:3", 4.0/3), .ratio("16:9", 16.0/9),
         .ratio("9:16", 9.0/16), .ratio("3:4", 3.0/4),
         .pixels("1920×1080", 1920, 1080), .pixels("1080×1920", 1080, 1920)]
    }

    public var label: String {
        switch self {
        case .free: return "自由"
        case .ratio(let name, _): return name
        case .pixels(let name, _, _): return name
        }
    }
}

@MainActor public final class MacShotController {
    public static let shared = MacShotController()

    public var outputDirectory: URL = {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return (pictures ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("MacAppControlDeck", isDirectory: true)
    }()

    public var recordingDirectory: URL = {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        return (movies ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("MacAppControlDeck", isDirectory: true)
    }()

    public private(set) var isRecording = false
    public private(set) var recordingFormat: RecordingFormat = .mp4
    public var recordingOptions = RecordingOptions()
    public var imageFormat = "png"
    public var imageQuality = 0.9
    public var captureDelay: TimeInterval = 0
    public var selectionPreset: CaptureSelectionPreset = .free
    public var playShutterSound = true
    public var saveToFile = true
    public var copyToClipboard = true
    public var showFloatingThumbnail = true
    private var recordingEngine: RecordingEngine?
    var overlayController: OverlayWindowController?
    private var recordingTarget: RecordingTarget?
    private var recordingIntent: RecordingFormat = .mp4
    private var toastPanel: NSPanel?
    private var toastTimer: Timer?
    private var delayCountdownWindow: NSWindow?
    private var delayCountdownTimer: Timer?
    private var delayEscMonitor: Any?

    // MARK: - 截图

    /// 截图延时：先在全屏中央显示倒计时，结束后再开始抓屏流程。
    /// 与上游一致，按 Esc 可取消本次截图。
    private func runWithCaptureDelay(_ action: @escaping @MainActor () -> Void) {
        let seconds = Int(captureDelay)
        guard seconds > 0,
              let screen = NSScreen.preferred ?? NSScreen.main else {
            action()
            return
        }
        cancelDelayCountdown()

        let size = NSSize(width: 140, height: 140)
        let origin = NSPoint(x: screen.frame.midX - size.width / 2,
                             y: screen.frame.midY - size.height / 2)
        let window = NSWindow(contentRect: NSRect(origin: origin, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = CountdownView(frame: NSRect(origin: .zero, size: size))
        view.remaining = seconds
        window.contentView = view
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        delayCountdownWindow = window

        delayEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.cancelDelayCountdown()
            return nil
        }

        var remaining = seconds
        delayCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            remaining -= 1
            guard let self else { timer.invalidate(); return }
            if remaining <= 0 {
                self.cancelDelayCountdown()
                action()
            } else {
                view.remaining = remaining
                view.needsDisplay = true
            }
        }
    }

    private func cancelDelayCountdown() {
        delayCountdownTimer?.invalidate()
        delayCountdownTimer = nil
        delayCountdownWindow?.orderOut(nil)
        delayCountdownWindow = nil
        if let monitor = delayEscMonitor {
            NSEvent.removeMonitor(monitor)
            delayEscMonitor = nil
        }
    }

    public func captureFullScreen() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            OverlayCoordinator.shared.beginOverlay(fullScreen: true)
        }
    }

    public func captureAllScreens() {
        guard ensurePermission() else { return }
        guard let image = LegacyScreenCaptureService.captureAllScreensStitched() else {
            showPermissionAlert()
            return
        }
        openEditor(image)
    }

    public func captureArea() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            self.overlayController = OverlayCoordinator.shared.beginOverlay()
        }
    }

    public func captureWindow() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            self.overlayController = OverlayCoordinator.shared.beginOverlay()
        }
    }

    public func quickSaveArea() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            self.overlayController = OverlayCoordinator.shared.beginOverlay(auto: .quickSave)
        }
    }

    public func quickOCRArea() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            self.overlayController = OverlayCoordinator.shared.beginOverlay(auto: .ocr)
        }
    }

    public func scrollCapture() {
        guard ensurePermission() else { return }
        runWithCaptureDelay {
            OverlayCoordinator.shared.beginScrollSelection()
        }
    }

    public func openRecentCapture(_ url: URL) {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            showAlert("打开失败", "文件可能已被移动或删除。")
            return
        }
        openEditor(cg)
    }

    private func scheduleCapture(_ action: @escaping () -> Void) {
        action()
    }

    func overlayControllerDidFinish(_ controller: OverlayWindowController) {
        if overlayController === controller { overlayController = nil }
    }

    public func openEditor(_ image: CGImage) {
        DetachedEditorWindowController.open(image: NSImage(cgImage: image,
            size: NSSize(width: image.width, height: image.height)))
    }

    func saveEditedImage(_ image: CGImage) {
        saveCapturedImage(image, annotationData: nil)
    }

    func saveCapturedImage(_ image: CGImage, annotationData: CaptureAnnotationData?) {
        let ext = imageFormat == "jpeg" ? "jpg" : imageFormat
        var savedURL: URL?
        do {
            if saveToFile {
                let template = FilenameFormatter.template(forRecording: false)
                let url = try FilenameFormatter.makeURL(directory: outputDirectory,
                                                        template: template,
                                                        fileExtension: ext)
                try CaptureExporter.write(image, to: url, format: imageFormat, quality: imageQuality)
                savedURL = url
                CaptureHistoryStore.shared.add(url)
            }
            if copyToClipboard || !saveToFile {
                CaptureExporter.copyToPasteboard(image)
            }
            if playShutterSound { CaptureSound.shared.play() }
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            var entryID: String?
            if saveToFile || true {
                entryID = ScreenshotHistory.shared.add(image: nsImage,
                                                       rawImage: nsImage,
                                                       annotations: annotationData?.annotations)
            }
            if showFloatingThumbnail || !showFloatingThumbnail {
                OverlayCoordinator.shared.showFloatingThumbnail(
                    image: nsImage, annotationData: annotationData, historyEntryID: entryID)
            }
            if let savedURL {
                showToast(copyToClipboard
                    ? "已保存 \(savedURL.lastPathComponent)，并复制到剪贴板"
                    : "已保存 \(savedURL.lastPathComponent)")
            } else {
                showToast("已复制到剪贴板")
            }
        } catch {
            showAlert("保存失败", error.localizedDescription)
        }
    }

    /// 从历史记录重新打开最近一次编辑。
    public func reopenLastEditSession() {
        guard let entry = ScreenshotHistory.shared.entries
            .sorted(by: { $0.timestamp > $1.timestamp }).first else {
            showToast("还没有可恢复的编辑记录")
            return
        }
        guard let image = ScreenshotHistory.shared.loadImage(for: entry) else {
            showToast("历史图片已不存在")
            return
        }
        DetachedEditorWindowController.open(image: image, historyEntryID: entry.id)
    }

    public func startRecording(format: RecordingFormat,
                        target mode: RecordingTargetMode = .area) {
        guard !isRecording else {
            stopRecording()
            return
        }
        guard ensurePermission() else { return }
        recordingIntent = format

        switch mode {
        case .fullScreen:
            guard let screen = NSScreen.main else { return }
            runWithCaptureDelay { [weak self] in
                self?.beginRecording(target: .screen(screen), format: format)
            }
        case .area:
            OverlayCoordinator.shared.beginRecordingSelection(initialFormat: format)
        case .window:
            LegacyWindowSelectionController.shared.begin { [weak self] target in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.beginRecording(target: .window(target), format: format)
                }
            }
        }
    }

    public func stopRecording() {
        Task { @MainActor in
            recordingEngine?.stopRecording()
        }
    }

    func beginRecording(target: RecordingTarget, format: RecordingFormat,
                        fpsOverride: Int? = nil, appName: String? = nil, hideHUD: Bool = false) {
        Task { @MainActor in
        recordingIntent = (format == .gif) ? .gif : recordingIntent
        let options = recordingOptions
        let fps = fpsOverride ?? options.fps
        let effectiveFormat: RecordingFormat = (recordingIntent == .gif) ? .gif : format

        let engine = RecordingEngine()
        let anchor = Self.anchor(for: target)
        // 默认显示 HUD；用户在覆盖层勾选“隐藏 HUD”时跳过，停止入口仍在菜单栏。
        if !hideHUD {
            RecordingHUDController.shared.show(
                format: effectiveFormat,
                relativeTo: anchor.rect,
                screen: anchor.screen,
                onTogglePause: { paused in
                    if paused { engine.pauseRecording() } else { engine.resumeRecording() }
                },
                onStop: { [weak self] in self?.stopRecording() })
        }
        let excluded = hideHUD ? [] : RecordingHUDController.shared.windowNumbers

        engine.onCompletion = { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                self.isRecording = false
                self.recordingEngine = nil
                self.recordingTarget = nil
                RecordingHUDController.shared.hide()
                ClickHighlightController.shared.stop()
                if let error {
                    self.showAlert("录制失败", error.localizedDescription)
                    return
                }
                guard let url else {
                    self.showAlert("录制失败", "没有生成录制文件。")
                    return
                }
                // 与菜单栏承诺一致：MP4 录制完成后同时落到 ~/Movies/MacAppControlDeck。
                // 编辑器仍使用会话内的原始 take，复制件供 Finder/其他应用直接使用。
                var publishedURL: URL?
                if self.recordingIntent != .gif {
                    publishedURL = self.publishRecording(url, appName: appName)
                }
                self.showToast(self.recordingIntent == .gif
                    ? "录制完成，正在准备 GIF 编辑"
                    : (publishedURL.map { "已保存 \($0.lastPathComponent)，正在打开编辑器" }
                        ?? "录制完成，正在打开编辑器"))
                VideoEditorWindowController.open(
                    url: url,
                    deleteOnClose: false,
                    exportFormat: self.recordingIntent == .gif ? .gif : nil)
            }
        }
        self.recordingEngine = engine
        self.recordingTarget = target
        self.recordingFormat = effectiveFormat
        self.isRecording = true

        // 只有“区域”录制需要按选区裁剪；全屏/窗口沿用对应范围。
        switch target {
        case .area(let screen, let rect):
            engine.startRecording(rect: rect, screen: screen,
                                  fpsOverride: fps, excludeWindowNumbers: excluded,
                                  appName: appName)
        case .screen(let screen):
            engine.startRecording(rect: screen.frame, screen: screen,
                                  fpsOverride: fps, excludeWindowNumbers: excluded,
                                  appName: appName)
        case .window(let window):
            let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: window.bounds.midX,
                                                                            y: window.bounds.midY)) }
            if let screen {
                engine.startRecording(rect: window.bounds, screen: screen,
                                      fpsOverride: fps, excludeWindowNumbers: excluded,
                                      appName: appName)
            } else {
                self.isRecording = false
                self.recordingEngine = nil
                RecordingHUDController.shared.hide()
                showAlert("录制失败", "找不到窗口所在显示器。")
            }
        }

        if UserDefaults.standard.object(forKey: "recordMouseHighlight") as? Bool ?? true {
            ClickHighlightController.shared.start()
        }
        }
    }

    private func publishRecording(_ source: URL, appName: String?) -> URL? {
        do {
            try FileManager.default.createDirectory(at: recordingDirectory,
                                                    withIntermediateDirectories: true)
            let destination = try FilenameFormatter.makeURL(
                directory: recordingDirectory,
                template: FilenameFormatter.template(forRecording: true),
                appName: appName,
                fileExtension: "mp4")
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            showToast("录制已保留在会话目录，复制到影片文件夹失败：\(error.localizedDescription)")
            return nil
        }
    }

    private static func anchor(for target: RecordingTarget) -> (rect: CGRect, screen: NSScreen?) {
        switch target {
        case .screen(let screen):
            return (screen.frame, screen)
        case .area(let screen, let rect):
            return (rect, screen)
        case .window(let window):
            let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            let screen = NSScreen.screens.first { $0.frame.contains(center) }
            return (window.bounds, screen)
        }
    }

    // MARK: - 权限/提示

    /// 不再用 CGPreflightScreenCaptureAccess 阻塞判断：重签名后它会误报未授权，
    /// 但真实抓屏往往仍然可用。这里直接放行，只有抓图失败时才提示授权。
    public func ensurePermission() -> Bool { true }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "请在系统设置 → 隐私与安全 → 屏幕录制中勾选「Mac 应用快捷控制台」，然后重启应用。\n\n若开关已经是打开状态，多半是重新构建后签名变化导致系统保留了旧条目：先删除列表里的旧条目，再重新添加本应用；或执行 Build/setup-signing.sh 使用固定证书后重新授权一次。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    public func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastPanel?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = CGRect(x: 14, y: 10, width: 360, height: 18)

        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 388, height: 38),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 388, height: 38))
        panel.contentView?.addSubview(label)

        let visible = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(CGPoint(x: visible.midX - 194, y: visible.minY + 48))
        panel.orderFrontRegardless()
        toastPanel = panel

        toastTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.toastPanel?.orderOut(nil)
            self?.toastPanel = nil
        }
    }
}

public enum RecordingTargetMode {
    case fullScreen
    case area
    case window
}
