import AppKit
import CoreGraphics

public final class MacShotController {
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
    private var recorder: ScreenRecorder?
    private var recordingTarget: RecordingTarget?
    private var toastPanel: NSPanel?
    private var toastTimer: Timer?

    // MARK: - 截图

    public func captureFullScreen() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                guard let image = ScreenCaptureService.captureFullScreen() else {
                    self?.showAlert("截图失败", "请确认屏幕录制权限已授权，并重启应用后重试。")
                    return
                }
                self?.openEditor(image)
            }
        }
    }

    public func captureArea() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            AreaSelectionController.shared.begin { [weak self] screen, rect in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = ScreenCaptureService.capture(area: rect, on: screen) else {
                        self?.showAlert("区域截图失败", "没有拿到选区图像，请重试。")
                        return
                    }
                    self?.openEditor(image)
                }
            }
        }
    }

    public func captureWindow() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            WindowSelectionController.shared.begin { [weak self] target in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = ScreenCaptureService.capture(window: target) else {
                        self?.showAlert("窗口截图失败", "窗口可能已关闭，请重试。")
                        return
                    }
                    self?.openEditor(image)
                }
            }
        }
    }

    /// 快速截图：选区后直接保存并复制，不打开编辑器。
    public func quickSaveArea() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            AreaSelectionController.shared.begin { [weak self] screen, rect in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let self,
                          let image = ScreenCaptureService.capture(area: rect, on: screen)
                    else { return }
                    self.saveEditorImage(image, notify: true)
                }
            }
        }
    }

    /// 快速 OCR：选区后直接识别文字并复制到剪贴板。
    public func quickOCRArea() {
        guard ensurePermission() else { return }
        scheduleCapture {
            AreaSelectionController.shared.begin { screen, rect in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = ScreenCaptureService.capture(area: rect, on: screen)
                    else { return }
                    OCRResultController.shared.recognize(image, autoCopy: true)
                }
            }
        }
    }

    public func scrollCapture() {
        guard ensurePermission() else { return }
        scheduleCapture {
            ScrollCaptureController.shared.begin()
        }
    }

    public func openRecentCapture(_ url: URL) {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            showAlert("无法打开", "截图文件可能已被移动或删除。")
            return
        }
        openEditor(cgImage)
    }

    private func scheduleCapture(_ action: @escaping () -> Void) {
        guard captureDelay > 0 else {
            action()
            return
        }
        showToast("\(Int(captureDelay)) 秒后截图…")
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay, execute: action)
    }

    func openEditor(_ image: CGImage) {
        CaptureEditorWindowController.shared.show(image: image)
    }

    func saveEditedImage(_ image: CGImage) {
        saveEditorImage(image, notify: true)
    }

    private func saveEditorImage(_ image: CGImage, notify: Bool) {
        do {
            let ext = imageFormat == "jpeg" ? "jpg" : imageFormat
            let url = try nextFileURL(in: outputDirectory, prefix: "Screenshot", ext: ext)
            try CaptureExporter.write(image, to: url, format: imageFormat, quality: imageQuality)
            CaptureExporter.copyToPasteboard(image)
            CaptureHistoryStore.shared.add(url)
            if notify { showToast("已保存 \(url.lastPathComponent)，并复制到剪贴板") }
        } catch {
            showAlert("保存失败", error.localizedDescription)
        }
    }

    // MARK: - 录屏

    public func startRecording(format: RecordingFormat,
                        target mode: RecordingTargetMode = .area) {
        guard !isRecording else {
            stopRecording()
            return
        }
        guard ensurePermission() else { return }

        switch mode {
        case .fullScreen:
            guard let screen = NSScreen.main else { return }
            beginRecording(target: .screen(screen), format: format)
        case .area:
            AreaSelectionController.shared.begin { [weak self] screen, rect in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.beginRecording(target: .area(screen, rect), format: format)
                }
            }
        case .window:
            WindowSelectionController.shared.begin { [weak self] target in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.beginRecording(target: .window(target), format: format)
                }
            }
        }
    }

    public func stopRecording() {
        recorder?.stop()
    }

    private func beginRecording(target: RecordingTarget, format: RecordingFormat) {
        let ext = format == .gif ? "gif" : "mp4"
        let prefix = format == .gif ? "Recording" : "Screen Recording"
        let url: URL
        do {
            try FileManager.default.createDirectory(at: recordingDirectory,
                                                    withIntermediateDirectories: true)
            url = try nextFileURL(in: recordingDirectory, prefix: prefix, ext: ext)
        } catch {
            showAlert("录制失败", error.localizedDescription)
            return
        }

        let recorder = ScreenRecorder()
        recorder.onFinish = { [weak self] result in
            Task { @MainActor in
                self?.isRecording = false
                self?.recorder = nil
                self?.recordingTarget = nil
                RecordingHUDController.shared.hide()
                switch result {
                case .success(let url):
                    self?.showToast("已保存 \(url.lastPathComponent)")
                case .failure(let error):
                    self?.showAlert("录制失败", error.localizedDescription)
                }
            }
        }
        self.recorder = recorder
        self.recordingTarget = target
        self.recordingFormat = format

        Task { @MainActor in
            do {
                try await recorder.start(target: target,
                                         format: format,
                                         options: recordingOptions,
                                         outputURL: url)
                self.isRecording = true
                let anchor = Self.anchor(for: target)
                RecordingHUDController.shared.show(
                    format: format,
                    relativeTo: anchor.rect,
                    screen: anchor.screen,
                    onTogglePause: { paused in
                        recorder.setPaused(paused)
                    },
                    onStop: { [weak self] in
                        self?.stopRecording()
                    })
            } catch {
                self.recorder = nil
                self.recordingTarget = nil
                self.isRecording = false
                self.showAlert("无法开始录制", error.localizedDescription)
            }
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

    public func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        _ = CGRequestScreenCaptureAccess()
        showPermissionAlert()
        return false
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "请在系统设置 → 隐私与安全 → 屏幕录制中勾选「Mac 应用快捷控制台」，然后重启应用。"
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

    private func nextFileURL(in directory: URL, prefix: String, ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return directory.appendingPathComponent("\(prefix) \(formatter.string(from: Date())).\(ext)")
    }
}

public enum RecordingTargetMode {
    case fullScreen
    case area
    case window
}
